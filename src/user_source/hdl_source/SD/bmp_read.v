// RGB24 reader: bilinear enlargement; native/large images retain the fast path.
// Positive-height BI_RGB, 1..1920 x 1..1080. Output bottom-up 640x480.
// Decoded row cache replays duplicate source rows during upscaling.
// The SDRAM writer flips rows. A sector cache handles padding/boundaries.
module bmp_read #(parameter ENABLE_SCAN=1,OUT_W=640, OUT_H=480, TIMEOUT_CYCLES=100000000)(
 input clk,rst, output ready,
 input scan_start, input [31:0] scan_start_sector,scan_max_sector,
 input [2:0] scan_target_count,
 output reg scan_done,scan_found_valid, output reg [31:0] scan_found_sector,
 output reg [2:0] scan_found_total,
 output reg [31:0] scan_resume_sector,
 input load_start, input [31:0] load_sector,
 input sd_init_done, output reg [3:0] state_code,
 input [15:0] bmp_width,bmp_height,
 output reg [15:0] source_width,source_height, output reg load_error,
 output reg write_req, input write_req_ack,write_ready,
 output reg sd_sec_read, output reg [31:0] sd_sec_read_addr,
 input [7:0] sd_sec_read_data, input sd_sec_read_data_valid,sd_sec_read_end,
 output reg [9:0] warning_top,output warning_format,
 input aspect_fit,output reg bmp_data_wr_en, output reg [23:0] bmp_data,output reg [7:0] bmp_overlay
);
localparam IDLE=0,HDR_WAIT=1,HDR_CHECK=2,ACK=3,ACK_DROP=4,
 BYTE_LOOK=5,CACHE_WAIT=6,BYTE_PIPE=7,BYTE_USE=8,EMIT=9,
 STEP_X=10,STEP_Y=11,ROW_START=12,FINISH=13,ROW_REPLAY_PIPE=14,ROW_REPLAY=15,HQ_WAIT=16,FIT_SIZE=17,FIT_PIXEL=18,FIT_EMIT=19,FIT_STEP=20,FIT_ROW=21;
reg [4:0] state;
reg scanning;
reg fit_active,fit_wide;
reg [10:0] fit_w,fit_h,fit_left,fit_bottom;
reg [22:0] fit_remainder;reg [10:0] fit_divisor;
reg [10:0] fit_quotient;


reg hq_active,hq_start,hq_byte_valid;
reg [7:0] hq_byte_data;
wire hq_byte_req,hq_pixel_valid,hq_done;
wire [31:0] hq_byte_addr;
wire [23:0] hq_pixel;
reg [9:0] byte_count;
reg sig0_ok,sig1_ok;
reg [3:0] overlay_tag;
reg [31:0] file_len,pixel_offset,dib_size;
reg [10:0] width,height;
reg [5:0] dimension_ok;
// Compare fixed-value header fields as bytes arrive; do not retain unused bits.
reg [3:0] compression_ok;
reg [1:0] planes_ok;
reg [15:0] bits;
wire packed_overlay=bits==32 && (&overlay_tag) && width==OUT_W && height==OUT_H;
assign warning_format=packed_overlay && pixel_offset==64 && warning_top<=640 && !warning_top[0];
reg [31:0] scan_sector,file_sector,cache_sector;
reg cache_valid;
reg [7:0] cache [0:511];
reg [7:0] cache_q;
reg x_advanced,y_advanced;
// Only decoded rows are stored, so reuse costs 640*24 bits regardless of input size.
// Accepted files are <=8 MiB; 24-bit relative addresses retain a spare bit.
reg [23:0] row_addr,pixel_addr,byte_addr;
reg [12:0] stride;
reg [11:0] x_acc,y_acc;
reg [10:0] ox,oy;
wire fit_inside=ox>=fit_left && ox<fit_left+fit_w && oy>=fit_bottom && oy<fit_bottom+fit_h;
reg [1:0] component;
reg [7:0] blue,green;
reg [$clog2(TIMEOUT_CYCLES+1)-1:0] watchdog;
reg [1:0] ack_sync;
bmp_bilinear #(.OUT_W(OUT_W),.OUT_H(OUT_H)) upscale(
 .clk(clk),.rst(rst || !hq_active),.start(hq_start),
 .width(source_width),.height(source_height),.stride(stride),.offset(pixel_offset),
 .byte_req(hq_byte_req),.byte_addr(hq_byte_addr),.byte_valid(hq_byte_valid),.byte_data(hq_byte_data),
 .pixel_valid(hq_pixel_valid),.pixel_ready(write_ready && state==HQ_WAIT),.pixel(hq_pixel),.done(hq_done));
wire [12:0] stride_calc = packed_overlay ? (OUT_W*4) : (({2'b0,width[10:0]} + ({2'b0,width[10:0]}<<1) + 13'd3) & 13'h1ffc);
// Header fields settle hundreds of cycles before sector completion.
// Pipeline the size validation instead of multiplying/adding/comparing at once.
reg [31:0] image_bytes,minimum_offset;
reg [32:0] image_end;
always @(posedge clk) begin
 image_bytes<=stride_calc*height[10:0];
 image_end<={1'b0,pixel_offset}+{1'b0,image_bytes};
 minimum_offset<=dib_size+32'd14;
end
reg valid_header;
wire header_check_value = sig0_ok && sig1_ok && dib_size>=40 && dib_size<=4082 && pixel_offset>=minimum_offset &&
 (&dimension_ok) && width>=1 && width<=1920 && height>=1 && height<=1080 &&
 (&planes_ok) && (bits==24 || packed_overlay) && (&compression_ok) && pixel_offset>=54 && pixel_offset<=4096 &&
 {1'b0,file_len}>=image_end && file_len<=32'd8388608;
wire [31:0] sectors_in_file=(file_len+511)>>9;
wire hint_valid;
wire [31:0] hint_sector;
generate if(ENABLE_SCAN) begin:raw_scan
scan_address_hint address_hint(.clk(clk),.rst(rst),
 .restart(scan_start && scan_start_sector==0),.header_check(state==HDR_CHECK && scanning),
 .byte_valid(state==HDR_WAIT && scanning && sd_sec_read_data_valid),
 .byte_index(byte_count),.byte_data(sd_sec_read_data),.sector(scan_sector),
 .jump_valid(hint_valid),.jump_sector(hint_sector));
end else begin:no_raw_scan
 assign hint_valid=0;assign hint_sector=0;
end endgenerate
wire [31:0] scan_increment=valid_header ? sectors_in_file : 32'd1;
wire [31:0] next_sector=!valid_header && hint_valid && hint_sector>scan_sector ?
 hint_sector : scan_sector+scan_increment;
assign ready=state==IDLE;
// Synchronous RAM without an array reset permits block RAM inference.
always @(posedge clk) begin
 if((state==HDR_WAIT || state==CACHE_WAIT) && sd_sec_read_data_valid)
  cache[byte_count[8:0]]<=sd_sec_read_data;
 cache_q<=cache[byte_addr[8:0]];
end
always @(posedge clk or posedge rst)
 if(rst) ack_sync<=0; else ack_sync<={ack_sync[0],write_req_ack};
always @(posedge clk or posedge rst) begin
 if(rst) begin
  state<=IDLE; hq_active<=0;hq_start<=0;hq_byte_valid<=0;hq_byte_data<=0;scanning<=0;fit_active<=0;fit_wide<=0;fit_w<=OUT_W;fit_h<=OUT_H;fit_left<=0;fit_bottom<=0;fit_remainder<=0;fit_divisor<=1;fit_quotient<=0; byte_count<=0; sig0_ok<=0; sig1_ok<=0;
  file_len<=0; pixel_offset<=0; dib_size<=0; width<=0; height<=0;dimension_ok<=0;
  overlay_tag<=0;bmp_overlay<=0;valid_header<=0;warning_top<=0;
  compression_ok<=0; planes_ok<=0; bits<=0; scan_sector<=0; file_sector<=0;
  cache_sector<=0; cache_valid<=0; row_addr<=0; pixel_addr<=0; byte_addr<=0;
  x_advanced<=0;y_advanced<=0;stride<=0; x_acc<=0; y_acc<=0; ox<=0; oy<=0; component<=0;
  blue<=0; green<=0; watchdog<=0;
  scan_done<=0; scan_found_valid<=0; scan_found_sector<=0; scan_found_total<=0; scan_resume_sector<=0;
  state_code<=0; source_width<=0; source_height<=0; load_error<=0;
  write_req<=0; sd_sec_read<=0; sd_sec_read_addr<=0;
  bmp_data_wr_en<=0; bmp_data<=0;
 end else begin
  scan_found_valid<=0; bmp_data_wr_en<=0; load_error<=0;hq_start<=0;hq_byte_valid<=0;
  if(state==IDLE || sd_sec_read_data_valid || sd_sec_read_end || bmp_data_wr_en) watchdog<=0;
  else watchdog<=watchdog+1'b1;
  if(!sd_init_done) begin
   hq_active<=0;
   state<=IDLE; sd_sec_read<=0; scan_done<=0; state_code<=0; write_req<=0; cache_valid<=0;
  end else if(state!=IDLE && watchdog>=TIMEOUT_CYCLES-1) begin
   hq_active<=0;
   state<=IDLE; sd_sec_read<=0; state_code<=14; write_req<=0; load_error<=!scanning;
   if(scanning) scan_done<=1;
  end else case(state)
   IDLE: begin
    hq_active<=0;
    write_req<=0; sd_sec_read<=0;
    if((ENABLE_SCAN && scan_start) || load_start) begin
     bmp_overlay<=0;overlay_tag<=0;warning_top<=0;
     scanning<=ENABLE_SCAN && scan_start; byte_count<=0; cache_valid<=0;
     if(ENABLE_SCAN && scan_start) begin
      scan_sector<=scan_start_sector; sd_sec_read_addr<=scan_start_sector;
      scan_done<=0; scan_found_total<=0; state_code<=2;
     end else begin
      file_sector<=load_sector; sd_sec_read_addr<=load_sector; state_code<=3;
     end
     sd_sec_read<=1; state<=HDR_WAIT;
    end
   end
   HDR_WAIT: begin
    if(sd_sec_read_data_valid) begin
     sd_sec_read<=0;
     byte_count<=byte_count+1'b1;
     case(byte_count)
      0:sig0_ok<=sd_sec_read_data==8'h42; 1:sig1_ok<=sd_sec_read_data==8'h4d;
      2:file_len[7:0]<=sd_sec_read_data; 3:file_len[15:8]<=sd_sec_read_data;
      4:file_len[23:16]<=sd_sec_read_data; 5:file_len[31:24]<=sd_sec_read_data;
      6:overlay_tag[0]<=sd_sec_read_data==8'h4f;7:overlay_tag[1]<=sd_sec_read_data==8'h56;
      8:overlay_tag[2]<=sd_sec_read_data==8'h4c;9:overlay_tag[3]<=sd_sec_read_data==8'h39;
      10:pixel_offset[7:0]<=sd_sec_read_data; 11:pixel_offset[15:8]<=sd_sec_read_data;
      12:pixel_offset[23:16]<=sd_sec_read_data; 13:pixel_offset[31:24]<=sd_sec_read_data;
      14:dib_size[7:0]<=sd_sec_read_data; 15:dib_size[15:8]<=sd_sec_read_data;
      16:dib_size[23:16]<=sd_sec_read_data; 17:dib_size[31:24]<=sd_sec_read_data;
      18:width[7:0]<=sd_sec_read_data;
      19:begin width[10:8]<=sd_sec_read_data[2:0];dimension_ok[0]<=sd_sec_read_data[7:3]==0;end
      20:dimension_ok[1]<=sd_sec_read_data==0;21:dimension_ok[2]<=sd_sec_read_data==0;
      22:height[7:0]<=sd_sec_read_data;
      23:begin height[10:8]<=sd_sec_read_data[2:0];dimension_ok[3]<=sd_sec_read_data[7:3]==0;end
      24:dimension_ok[4]<=sd_sec_read_data==0;25:dimension_ok[5]<=sd_sec_read_data==0;
      26:planes_ok[0]<=sd_sec_read_data==1; 27:planes_ok[1]<=sd_sec_read_data==0;
      28:bits[7:0]<=sd_sec_read_data; 29:bits[15:8]<=sd_sec_read_data;
      30:compression_ok[0]<=sd_sec_read_data==0; 31:compression_ok[1]<=sd_sec_read_data==0;
      32:compression_ok[2]<=sd_sec_read_data==0; 33:compression_ok[3]<=sd_sec_read_data==0;
      54:warning_top[7:0]<=sd_sec_read_data;
      55:warning_top[9:8]<=sd_sec_read_data[1:0];
     endcase
    end
    if(sd_sec_read_end) begin
     sd_sec_read<=0;
     if(byte_count==512 || (byte_count==511 && sd_sec_read_data_valid)) begin
      // Header bytes 0..33 are stable before sector completion. Register the
      // validation before the scanner address adder to keep the 100 MHz path short.
      valid_header<=header_check_value;
      cache_sector<=sd_sec_read_addr;cache_valid<=1;state<=HDR_CHECK;
     end else begin state<=IDLE;state_code<=14;load_error<=!scanning;if(scanning) scan_done<=1;end
    end
   end
   HDR_CHECK: begin
    if(scanning) begin
     scan_resume_sector<=next_sector;
     if(valid_header) begin
      scan_found_valid<=1; scan_found_sector<=scan_sector; scan_found_total<=scan_found_total+1'b1;
     end
     if(next_sector>scan_max_sector || (valid_header && scan_found_total+1>=scan_target_count)) begin
      scan_done<=1; state<=IDLE; state_code<=(scan_found_total!=0 || valid_header) ? 1 : 15;
     end else begin
      scan_sector<=next_sector; sd_sec_read_addr<=next_sector;
      sd_sec_read<=1; byte_count<=0; state<=HDR_WAIT;
     end
    end else if(valid_header) begin
     hq_active<=!packed_overlay && aspect_fit!==1'b1 && width<=OUT_W && height<=OUT_H && (width<OUT_W || height<OUT_H);
     source_width<={5'd0,width}; source_height<={5'd0,height};
     stride<=stride_calc; row_addr<=pixel_offset; pixel_addr<=pixel_offset; byte_addr<=pixel_offset;
     ox<=0; oy<=0; x_acc<=0; y_acc<=0; component<=0;
     fit_active<=aspect_fit===1'b1 && !packed_overlay;
     if(aspect_fit===1'b1 && !packed_overlay) begin
      fit_wide<=width*OUT_H>=height*OUT_W;
      fit_remainder<=width*OUT_H>=height*OUT_W ? height*OUT_W : width*OUT_H;
      fit_divisor<=width*OUT_H>=height*OUT_W ? width[10:0] : height[10:0];
      fit_quotient<=0;state<=FIT_SIZE;
     end else begin write_req<=1;state<=ACK;end
    end else begin state<=IDLE; state_code<=14; load_error<=1; end
   end
   FIT_SIZE:begin
    // At most 640 subtracts; occurs once per image, outside the pixel path.
    if(fit_remainder>=fit_divisor) begin fit_remainder<=fit_remainder-fit_divisor;fit_quotient<=fit_quotient+1'b1;end
    else begin
     fit_w<=fit_wide ? OUT_W : (fit_quotient==0 ? 1 : fit_quotient);
     fit_h<=fit_wide ? (fit_quotient==0 ? 1 : fit_quotient) : OUT_H;
     fit_left<=fit_wide ? 0 : (OUT_W-(fit_quotient==0 ? 1 : fit_quotient))/2;
     fit_bottom<=fit_wide ? (OUT_H-(fit_quotient==0 ? 1 : fit_quotient))/2 : 0;
     write_req<=1;state<=ACK;
    end
   end
   FIT_PIXEL:begin
    if(fit_inside) begin byte_addr<=pixel_addr;component<=0;state<=BYTE_LOOK;end
    else begin bmp_data<=0;state<=FIT_EMIT;end
   end
   FIT_EMIT:if(write_ready) begin
    bmp_data_wr_en<=1;
    if(ox==OUT_W-1) begin
     ox<=0;x_acc<=0;
     if(oy==OUT_H-1) state<=FINISH;
     else begin
      oy<=oy+1'b1;
      if(oy>=fit_bottom && oy<fit_bottom+fit_h) y_acc<=y_acc+height[10:0];
      state<=FIT_ROW;
     end
    end else begin
     ox<=ox+1'b1;
     if(fit_inside) x_acc<=x_acc+width[10:0];
     state<=FIT_STEP;
    end
   end
   FIT_STEP:begin
    if(x_acc>=fit_w) begin x_acc<=x_acc-fit_w;pixel_addr<=pixel_addr+3;end
    else state<=FIT_PIXEL;
   end
   FIT_ROW:begin
    if(y_acc>=fit_h) begin y_acc<=y_acc-fit_h;row_addr<=row_addr+stride;end
    else begin pixel_addr<=row_addr;state<=FIT_PIXEL;end
   end
   ACK: if(ack_sync[1]) begin write_req<=0; state<=ACK_DROP; end
   ACK_DROP: if(!ack_sync[1]) begin
    if(hq_active) begin hq_start<=1;state<=HQ_WAIT;end
    else state<=fit_active ? FIT_PIXEL : BYTE_LOOK;
   end
   HQ_WAIT:begin
    if(hq_byte_req && !hq_byte_valid) begin byte_addr<=hq_byte_addr;state<=BYTE_LOOK;end
    if(hq_pixel_valid && write_ready) begin bmp_data<=hq_pixel;bmp_data_wr_en<=1;end
    if(hq_done) state<=FINISH;
   end
   BYTE_LOOK: begin
    if(cache_valid && cache_sector==file_sector+(byte_addr>>9)) state<=BYTE_USE;
    else begin
     sd_sec_read_addr<=file_sector+(byte_addr>>9); sd_sec_read<=1; byte_count<=0; state<=CACHE_WAIT;
    end
   end
   CACHE_WAIT: begin
    if(sd_sec_read_data_valid) begin sd_sec_read<=0;byte_count<=byte_count+1'b1;end
    if(sd_sec_read_end) begin
     sd_sec_read<=0;
     if(byte_count==512 || (byte_count==511 && sd_sec_read_data_valid)) begin
      cache_valid<=1;cache_sector<=sd_sec_read_addr;state<=BYTE_PIPE;
     end else begin state<=IDLE;state_code<=14;load_error<=1;end
    end
   end
   BYTE_PIPE: state<=BYTE_USE;
   BYTE_USE: begin
    if(hq_active) begin hq_byte_data<=cache_q;hq_byte_valid<=1;state<=HQ_WAIT;end
    else if(component==0) begin blue<=cache_q; component<=1; byte_addr<=byte_addr+1; state<=BYTE_LOOK; end
    else if(component==1) begin green<=cache_q; component<=2; byte_addr<=byte_addr+1; state<=BYTE_LOOK; end
    else if(component==2) begin
     bmp_data<={cache_q,green,blue};
     if(packed_overlay) begin component<=3;byte_addr<=byte_addr+1'b1;state<=BYTE_LOOK;end
     else begin bmp_overlay<=0;state<=fit_active ? FIT_EMIT : EMIT;end
    end else begin bmp_overlay<=cache_q;state<=EMIT;end
   end
   EMIT: if(write_ready) begin
    bmp_data_wr_en<=1; component<=0;x_advanced<=0;y_advanced<=0;
    if(ox==OUT_W-1) begin
     ox<=0; x_acc<=0;
     if(oy==OUT_H-1) state<=FINISH;
     else begin oy<=oy+1'b1; y_acc<=y_acc+height[10:0]; state<=STEP_Y; end
    end else begin ox<=ox+1'b1; x_acc<=x_acc+width[10:0]; state<=STEP_X; end
   end
   STEP_X: begin
    if(x_acc>=OUT_W) begin x_acc<=x_acc-OUT_W; pixel_addr<=pixel_addr+(packed_overlay ? 3'd4 : 3'd3);x_advanced<=1;end
    else if(!x_advanced) state<=EMIT;
    else begin byte_addr<=pixel_addr;state<=BYTE_LOOK;end
   end
   STEP_Y: begin
    if(y_acc>=OUT_H) begin y_acc<=y_acc-OUT_H;row_addr<=row_addr+stride;y_advanced<=1;end
    else if(y_advanced) state<=ROW_START;
    else state<=ROW_START;
   end
   ROW_START: begin pixel_addr<=row_addr; byte_addr<=row_addr; state<=BYTE_LOOK; end
   FINISH: begin hq_active<=0;state<=IDLE; state_code<=1; end
   default:state<=IDLE;
  endcase
 end
end
endmodule

