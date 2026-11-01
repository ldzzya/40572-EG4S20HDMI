// Contiguous RGB24 BMP reader with on-FPGA nearest-neighbour scaling.
// Positive-height BI_RGB, 1..1920 x 1..1080. Output bottom-up 640x480.
// The SDRAM writer flips rows. A sector cache handles padding/boundaries.
module bmp_read #(parameter OUT_W=640, OUT_H=480, TIMEOUT_CYCLES=100000000)(
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
 output reg bmp_data_wr_en, output reg [23:0] bmp_data
);
localparam IDLE=0,HDR_WAIT=1,HDR_CHECK=2,ACK=3,ACK_DROP=4,
 BYTE_LOOK=5,CACHE_WAIT=6,BYTE_PIPE=7,BYTE_USE=8,EMIT=9,
 STEP_X=10,STEP_Y=11,ROW_START=12,FINISH=13;
reg [3:0] state;
reg scanning;
reg [9:0] byte_count;
reg [7:0] sig0,sig1;
reg [31:0] file_len,pixel_offset,dib_size,width,height,compression;
reg [15:0] planes,bits;
reg [31:0] scan_sector,file_sector,cache_sector;
reg cache_valid;
reg [7:0] cache [0:511];
reg [7:0] cache_q;
reg [31:0] row_addr,pixel_addr,byte_addr;
reg [12:0] stride;
reg [11:0] x_acc,y_acc;
reg [9:0] ox,oy;
reg [1:0] component;
reg [7:0] blue,green;
reg [31:0] watchdog;
reg [1:0] ack_sync;
wire [12:0] stride_calc = (({2'b0,width[10:0]} + ({2'b0,width[10:0]}<<1) + 13'd3) & 13'h1ffc);
wire [31:0] image_bytes = stride_calc * height[10:0];
wire valid_header = sig0==8'h42 && sig1==8'h4d && dib_size>=40 &&
 width>=1 && width<=1920 && height>=1 && height<=1080 &&
 planes==1 && bits==24 && compression==0 && pixel_offset>=54 && pixel_offset<=4096 &&
 file_len>=pixel_offset+image_bytes && file_len<=32'd8388608;
wire [31:0] sectors_in_file=(file_len+511)>>9;
wire [31:0] next_sector=scan_sector+(valid_header ? sectors_in_file : 32'd1);
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
  state<=IDLE; scanning<=0; byte_count<=0; sig0<=0; sig1<=0;
  file_len<=0; pixel_offset<=0; dib_size<=0; width<=0; height<=0;
  compression<=0; planes<=0; bits<=0; scan_sector<=0; file_sector<=0;
  cache_sector<=0; cache_valid<=0; row_addr<=0; pixel_addr<=0; byte_addr<=0;
  stride<=0; x_acc<=0; y_acc<=0; ox<=0; oy<=0; component<=0;
  blue<=0; green<=0; watchdog<=0;
  scan_done<=0; scan_found_valid<=0; scan_found_sector<=0; scan_found_total<=0; scan_resume_sector<=0;
  state_code<=0; source_width<=0; source_height<=0; load_error<=0;
  write_req<=0; sd_sec_read<=0; sd_sec_read_addr<=0;
  bmp_data_wr_en<=0; bmp_data<=0;
 end else begin
  scan_found_valid<=0; bmp_data_wr_en<=0; load_error<=0;
  if(state==IDLE || sd_sec_read_data_valid || sd_sec_read_end || bmp_data_wr_en) watchdog<=0;
  else watchdog<=watchdog+1'b1;
  if(!sd_init_done) begin
   state<=IDLE; sd_sec_read<=0; scan_done<=0; state_code<=0; write_req<=0; cache_valid<=0;
  end else if(state!=IDLE && watchdog>=TIMEOUT_CYCLES-1) begin
   state<=IDLE; sd_sec_read<=0; state_code<=14; write_req<=0; load_error<=!scanning;
   if(scanning) scan_done<=1;
  end else case(state)
   IDLE: begin
    write_req<=0; sd_sec_read<=0;
    if(scan_start || load_start) begin
     scanning<=scan_start; byte_count<=0; cache_valid<=0;
     if(scan_start) begin
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
      0:sig0<=sd_sec_read_data; 1:sig1<=sd_sec_read_data;
      2:file_len[7:0]<=sd_sec_read_data; 3:file_len[15:8]<=sd_sec_read_data;
      4:file_len[23:16]<=sd_sec_read_data; 5:file_len[31:24]<=sd_sec_read_data;
      10:pixel_offset[7:0]<=sd_sec_read_data; 11:pixel_offset[15:8]<=sd_sec_read_data;
      12:pixel_offset[23:16]<=sd_sec_read_data; 13:pixel_offset[31:24]<=sd_sec_read_data;
      14:dib_size[7:0]<=sd_sec_read_data; 15:dib_size[15:8]<=sd_sec_read_data;
      16:dib_size[23:16]<=sd_sec_read_data; 17:dib_size[31:24]<=sd_sec_read_data;
      18:width[7:0]<=sd_sec_read_data; 19:width[15:8]<=sd_sec_read_data;
      20:width[23:16]<=sd_sec_read_data; 21:width[31:24]<=sd_sec_read_data;
      22:height[7:0]<=sd_sec_read_data; 23:height[15:8]<=sd_sec_read_data;
      24:height[23:16]<=sd_sec_read_data; 25:height[31:24]<=sd_sec_read_data;
      26:planes[7:0]<=sd_sec_read_data; 27:planes[15:8]<=sd_sec_read_data;
      28:bits[7:0]<=sd_sec_read_data; 29:bits[15:8]<=sd_sec_read_data;
      30:compression[7:0]<=sd_sec_read_data; 31:compression[15:8]<=sd_sec_read_data;
      32:compression[23:16]<=sd_sec_read_data; 33:compression[31:24]<=sd_sec_read_data;
     endcase
    end
    if(sd_sec_read_end) begin
     sd_sec_read<=0;
     if(byte_count==512 || (byte_count==511 && sd_sec_read_data_valid)) begin
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
     source_width<=width[15:0]; source_height<=height[15:0];
     stride<=stride_calc; row_addr<=pixel_offset; pixel_addr<=pixel_offset; byte_addr<=pixel_offset;
     ox<=0; oy<=0; x_acc<=0; y_acc<=0; component<=0; write_req<=1; state<=ACK;
    end else begin state<=IDLE; state_code<=14; load_error<=1; end
   end
   ACK: if(ack_sync[1]) begin write_req<=0; state<=ACK_DROP; end
   ACK_DROP: if(!ack_sync[1]) state<=BYTE_LOOK;
   BYTE_LOOK: begin
    if(cache_valid && cache_sector==file_sector+(byte_addr>>9)) state<=BYTE_PIPE;
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
    if(component==0) begin blue<=cache_q; component<=1; byte_addr<=byte_addr+1; state<=BYTE_LOOK; end
    else if(component==1) begin green<=cache_q; component<=2; byte_addr<=byte_addr+1; state<=BYTE_LOOK; end
    else begin bmp_data<={cache_q,green,blue}; state<=EMIT; end
   end
   EMIT: if(write_ready) begin
    bmp_data_wr_en<=1; component<=0;
    if(ox==OUT_W-1) begin
     ox<=0; x_acc<=0;
     if(oy==OUT_H-1) state<=FINISH;
     else begin oy<=oy+1'b1; y_acc<=y_acc+height[10:0]; state<=STEP_Y; end
    end else begin ox<=ox+1'b1; x_acc<=x_acc+width[10:0]; state<=STEP_X; end
   end
   STEP_X: begin
    if(x_acc>=OUT_W) begin x_acc<=x_acc-OUT_W; pixel_addr<=pixel_addr+3; end
    else begin byte_addr<=pixel_addr; state<=BYTE_LOOK; end
   end
   STEP_Y: begin
    if(y_acc>=OUT_H) begin y_acc<=y_acc-OUT_H; row_addr<=row_addr+stride; end
    else state<=ROW_START;
   end
   ROW_START: begin pixel_addr<=row_addr; byte_addr<=row_addr; state<=BYTE_LOOK; end
   FINISH: begin state<=IDLE; state_code<=1; end
   default:state<=IDLE;
  endcase
 end
end
endmodule
