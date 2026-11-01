`timescale 1ns/1ps
module tb_decode_720;
 reg clk=0;always #5 clk=~clk;reg rst=1,start=0;wire ready,req,read_req,we,error;
 wire [31:0] addr;wire [23:0] rgb;wire [7:0] mask;reg [7:0] data=0;reg valid=0,done=0;
 reg [7:0] disk[0:3686911];integer i,pos=0,base=0,cycles=0,pixels=0;reg busy=0;
 bmp_read #(.OUT_W(1280),.OUT_H(720),.TIMEOUT_CYCLES(20000)) dut(.clk(clk),.rst(rst),.ready(ready),
 .scan_start(1'b0),.scan_start_sector(32'd0),.scan_max_sector(32'd0),.scan_target_count(3'd1),
 .load_start(start),.load_sector(32'd0),.sd_init_done(1'b1),.bmp_width(16'd1280),.bmp_height(16'd720),
 .load_error(error),.write_req(req),.write_req_ack(req),.write_ready(cycles%17!=0),
 .sd_sec_read(read_req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(done),
 .aspect_fit(1'b1),.bmp_data_wr_en(we),.bmp_data(rgb),.bmp_overlay(mask));
 always @(posedge clk)begin
  cycles<=cycles+1;valid<=0;done<=0;
  if(rst)busy<=0;
  else if(!busy && read_req)begin busy<=1;base<=addr*512;pos<=0;end
  else if(busy && cycles%3!=0)begin
   if(pos<512)begin data<=disk[base+pos];valid<=1;pos<=pos+1;end
   else begin done<=1;busy<=0;end
  end
 end
 always @(negedge clk)begin
  if(error)$fatal(1,"720p header/read failure");
  if(we)begin
   if(rgb!==24'h426080 || mask!==disk[64+pixels*4+3])$fatal(1,"pixel %d RGB/mask mismatch %h/%h",pixels,rgb,mask);
   pixels=pixels+1;
  end
 end
 initial begin
  for(i=0;i<3686912;i=i+1)disk[i]=0;
  $readmemh("build/overlay_720/packed.hex",disk,0,3686463);
  repeat(5)@(negedge clk);rst=0;start=1;@(negedge clk);start=0;
  wait(!ready);wait(ready);repeat(4)@(negedge clk);
  if(pixels!=921600)$fatal(1,"truncated 720p frame %d",pixels);
  $display("PASS 720p decode: all 921600 RGB24/mask pixels, last column/row, fit mode, sector crossings and stalls");$finish;
 end
 initial begin #800000000;$fatal(1,"720p decode timeout %d %d",dut.state,pixels);end
endmodule
