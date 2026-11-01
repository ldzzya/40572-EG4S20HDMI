`timescale 1ns/1ps
module tb_warning_decode;
 reg clk=0;always #5 clk=~clk;reg rst=1,start=0,fit=1;wire ready,req,read_req,we,error;
 wire [31:0] addr;wire [23:0] rgb;wire [7:0] overlay;reg [7:0] data=0;reg valid=0,done=0;
 reg [7:0] disk[0:1229311];integer i,pos=0,base=0,cycles=0,pixels=0,phase=0;reg busy=0;
 bmp_read #(.TIMEOUT_CYCLES(20000)) dut(.clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),.scan_start_sector(32'd0),
 .scan_max_sector(32'd0),.scan_target_count(3'd1),.load_start(start),.load_sector(32'd0),.sd_init_done(1'b1),
 .bmp_width(16'd640),.bmp_height(16'd480),.load_error(error),.write_req(req),.write_req_ack(req),.write_ready(cycles%17!=0),
 .sd_sec_read(read_req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(valid),.sd_sec_read_end(done),
 .aspect_fit(fit),.bmp_data_wr_en(we),.bmp_data(rgb),.bmp_overlay(overlay));
 always @(posedge clk)begin
  cycles<=cycles+1;valid<=0;done<=0;
  if(rst)busy<=0;
  else if(!busy && read_req)begin busy<=1;base<=addr*512;pos<=0;end
  else if(busy && cycles%3!=0)begin
   if(pos<512)begin data<=disk[base+pos];valid<=1;pos<=pos+1;end
   else begin done<=1;busy<=0;end
  end
 end
 always @(negedge clk)if(we)begin
  if(phase==0)$fatal(1,"unmarked RGB32 accepted");
  if(phase==1)begin
   if(rgb!==24'h426080 || overlay!==disk[54+pixels*4+3])$fatal(1,"packed pixel %d %h %h",pixels,rgb,overlay);
  end else if(rgb!==24'h123456 || overlay!==0)$fatal(1,"ordinary image inherited overlay or changed RGB");
  pixels=pixels+1;
 end
 task load;begin pixels=0;start=1;@(negedge clk);start=0;wait(ready);repeat(4)@(negedge clk);end endtask
 initial begin
  for(i=0;i<1229312;i=i+1)disk[i]=0;
  $readmemh("build/warning_sim/packed.hex",disk,0,1228853);
  repeat(5)@(negedge clk);rst=0;disk[6]=0;load();if(pixels!=0)$fatal(1,"missing magic accepted");
  disk[6]="O";phase=1;load();if(pixels!=307200)$fatal(1,"packed frame truncated %d",pixels);
  $display("PASS warning decode: all 307200 RGB/mask pixels, stalls and sector crossings; unmarked RGB32 rejected");$fflush();
  $readmemh("build/warning_sim/ordinary.hex",disk,0,511);phase=2;fit=0;load();if(pixels!=307200)$fatal(1,"normal frame truncated");
  $display("PASS normal RGB24 after warning: 4x2 bilinear upscale, 307200 unchanged pixels, no stale overlay");$finish;
 end
 initial begin #300000000;$fatal(1,"decode timeout state=%d pixels=%d",dut.state,pixels);end
endmodule
