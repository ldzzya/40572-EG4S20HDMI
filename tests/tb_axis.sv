`timescale 1ns/1ps
module tb_axis;
reg clk=0,rst=1,vs=1,de=0;always #5 clk=~clk;
reg [23:0] rgb=0;wire valid,sof,last;wire [23:0] data;
video_rgb_to_axis_640x480 dut(clk,rst,vs,de,rgb,sof,valid,last,data);
integer x,y,pixels=0,ends=0,starts=0;
always @(posedge clk) begin
 #1;
 if(!rst && valid) begin
  if(last!==(pixels%640==639)) $fatal(1,"AXIS TLAST wrong at pixel %0d (x=%0d), got=%b",pixels,pixels%640,last);
  if(sof!==(pixels==0)) $fatal(1,"AXIS SOF wrong at pixel %0d",pixels);
  pixels=pixels+1;if(last) ends=ends+1;if(sof) starts=starts+1;
 end
end
initial begin
 repeat(5) @(negedge clk);rst=0;vs=0;repeat(3) @(negedge clk);vs=1;
 for(y=0;y<3;y=y+1) begin
  repeat(20) @(negedge clk);
  for(x=0;x<640;x=x+1) begin de=1;rgb=x;@(negedge clk);end
  de=0;
 end
 repeat(5) @(negedge clk);
 if(pixels!=1920 || ends!=3 || starts!=1) $fatal(1,"wrong markers");
 $display("PASS AXIS: exactly 640 pixels/line, TLAST at final pixel, one SOF per frame");$finish;
end
endmodule
