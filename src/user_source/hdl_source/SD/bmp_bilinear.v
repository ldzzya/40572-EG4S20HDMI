// Separable RGB24 bilinear enlargement with two rolling source-row buffers.
// Used only when both source axes fit the output; the native/large-image fast
// path stays in bmp_read. Every source row is fetched once, in file order.
// Q16 coordinate steps are calculated once with a sequential integer divider.
// Interpolation uses Q8 weights, rounding, clamped edges and endpoint alignment.
module bmp_bilinear #(parameter OUT_W=640,OUT_H=480)(
 input clk,rst,start,
 input [15:0] width,height,input [12:0] stride,input [31:0] offset,
 output byte_req,output [31:0] byte_addr,input byte_valid,input [7:0] byte_data,
 output pixel_valid,input pixel_ready,output [23:0] pixel,output done
);
 localparam IDLE=0,DIVIDE=1,CHECK_ROW=2,FETCH=3,STORE=4,
            ROW_BEGIN=5,LEFT_PIPE=6,RIGHT_PIPE=7,HORIZONTAL=8,VERTICAL=9,EMIT=10,DONE=11,
            ROW_PREP=12,RIGHT_CAPTURE=13;
 reg [3:0] state;
 reg axis;
 reg [5:0] div_count;
 reg [31:0] numerator,quotient;
 reg [10:0] remainder,denominator;
 wire [11:0] div_trial={remainder,numerator[31]};
 wire div_take=div_trial>={1'b0,denominator};
 wire [31:0] div_result={quotient[30:0],div_take};
 reg [16:0] x_step,y_step;
 reg [26:0] x_pos,y_pos;
 reg [10:0] ox,oy,next_row,load_x;
 reg [31:0] next_row_addr,fetch_addr;
 reg [1:0] component;
 reg [7:0] blue,green;
 reg [23:0] loaded_pixel;
 reg [10:0] sample_x;
 wire [23:0] even_q,odd_q;reg [23:0] left_even,left_odd;
 reg [23:0] right_even,right_odd;
 reg [23:0] horizontal_even,horizontal_odd,result;
 reg [7:0] wx,wy;reg odd_y,single_y;
 wire [10:0] sy=(oy==OUT_H-1) ? height-1'b1 : y_pos[26:16];
 wire [10:0] high_y=(sy+1<height) ? sy+1'b1 : sy;
 // One preparation cycle per output row separates coordinate clamping from
 // the fetch decision. The cached limit stays valid throughout that row.
 reg [10:0] row_high;
 wire [10:0] sx=(ox==OUT_W-1) ? width-1'b1 : x_pos[26:16];
 wire [10:0] high_x=(sx+1<width) ? sx+1'b1 : sx;
 wire [23:0] vertical_low=odd_y ? horizontal_odd : horizontal_even;
 wire [23:0] vertical_high=odd_y ? horizontal_even : horizontal_odd;
 assign byte_req=state==FETCH;
 assign byte_addr=fetch_addr;
 assign pixel_valid=state==EMIT;
 assign pixel=result;
 assign done=state==DONE;
 rgb_row_ram even_row(.clk(clk),.we(state==STORE && !next_row[0]),.wa(load_x),.wd(loaded_pixel),.ra(sample_x),.rd(even_q));
 rgb_row_ram odd_row(.clk(clk),.we(state==STORE && next_row[0]),.wa(load_x),.wd(loaded_pixel),.ra(sample_x),.rd(odd_q));
 function [7:0] blend;
  input [7:0] a,b,w;
  reg signed [8:0] delta;
  reg signed [17:0] sum;
  begin
   delta=$signed({1'b0,b})-$signed({1'b0,a});
   sum=$signed({1'b0,a,8'b0})+delta*$signed({1'b0,w})+18'sd128;
   blend=sum[15:8];
  end
 endfunction
 function [23:0] blend_rgb;
  input [23:0] a,b;input [7:0] w;
  begin blend_rgb={blend(a[23:16],b[23:16],w),blend(a[15:8],b[15:8],w),blend(a[7:0],b[7:0],w)};end
 endfunction
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   state<=IDLE;axis<=0;div_count<=0;numerator<=0;quotient<=0;remainder<=0;denominator<=0;
   x_step<=0;y_step<=0;x_pos<=0;y_pos<=0;ox<=0;oy<=0;next_row<=0;load_x<=0;
   next_row_addr<=0;fetch_addr<=0;component<=0;blue<=0;green<=0;loaded_pixel<=0;
   sample_x<=0;left_even<=0;left_odd<=0;horizontal_even<=0;horizontal_odd<=0;result<=0;wx<=0;wy<=0;odd_y<=0;single_y<=0;row_high<=0;
   right_even<=0;right_odd<=0;
  end else case(state)
   IDLE:if(start) begin
    axis<=0;div_count<=0;remainder<=0;quotient<=0;
    numerator<=({16'd0,width}-1'b1)<<16;denominator<=OUT_W-1;state<=DIVIDE;
    x_pos<=0;y_pos<=0;ox<=0;oy<=0;next_row<=0;next_row_addr<=offset;
   end
   DIVIDE:begin
    numerator<=numerator<<1;quotient<=div_result;
    remainder<=div_take ? div_trial-denominator : div_trial;
    if(div_count==31) begin
     if(!axis) begin
      x_step<=div_result[16:0];axis<=1;div_count<=0;remainder<=0;quotient<=0;
      numerator<=({16'd0,height}-1'b1)<<16;denominator<=OUT_H-1;
     end else begin y_step<=div_result[16:0];state<=ROW_PREP;end
    end else div_count<=div_count+1'b1;
   end
   ROW_PREP:begin row_high<=high_y;state<=CHECK_ROW;end
   CHECK_ROW:if(next_row<=row_high) begin
    load_x<=0;component<=0;fetch_addr<=next_row_addr;state<=FETCH;
   end else begin ox<=0;x_pos<=0;state<=ROW_BEGIN;end
   FETCH:if(byte_valid) begin
    fetch_addr<=fetch_addr+1'b1;
    if(component==0) begin blue<=byte_data;component<=1;end
    else if(component==1) begin green<=byte_data;component<=2;end
    else begin loaded_pixel<={byte_data,green,blue};state<=STORE;end
   end
   STORE:begin
    component<=0;
    if(load_x+1>=width) begin
     next_row<=next_row+1'b1;next_row_addr<=next_row_addr+stride;state<=CHECK_ROW;
    end else begin load_x<=load_x+1'b1;state<=FETCH;end
   end
   ROW_BEGIN:begin
    odd_y<=sy[0];single_y<=sy==row_high;
    sample_x<=sx;wx<=ox==OUT_W-1 ? 8'd0 : x_pos[15:8];
    wy<=oy==OUT_H-1 ? 8'd0 : y_pos[15:8];state<=LEFT_PIPE;
   end
   LEFT_PIPE:begin sample_x<=high_x;state<=RIGHT_PIPE;end
   RIGHT_PIPE:begin left_even<=even_q;left_odd<=odd_q;state<=RIGHT_CAPTURE;end
   // Separate BRAM output delay from subtract/multiply/add. One extra clock
   // per enlarged pixel; coordinates, Q8 rounding and ready/valid are unchanged.
   RIGHT_CAPTURE:begin right_even<=even_q;right_odd<=odd_q;state<=HORIZONTAL;end
   HORIZONTAL:begin
    horizontal_even<=blend_rgb(left_even,right_even,wx);
    horizontal_odd<=blend_rgb(left_odd,right_odd,wx);state<=VERTICAL;
   end
   VERTICAL:begin
    if(single_y) result<=vertical_low;
    else result<=blend_rgb(vertical_low,vertical_high,wy);
    state<=EMIT;
   end
   EMIT:if(pixel_ready) begin
    if(ox==OUT_W-1) begin
     if(oy==OUT_H-1) state<=DONE;
     else begin oy<=oy+1'b1;y_pos<=y_pos+y_step;state<=ROW_PREP;end
    end else begin ox<=ox+1'b1;x_pos<=x_pos+x_step;state<=ROW_BEGIN;end
   end
   DONE:state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule
