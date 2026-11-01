`timescale 1ns/1ps
module tb_presenter;
reg clk=0;always #5 clk=~clk;
reg rst=1,tick=0,req=0;reg [1:0] bufidx=0;
wire ack,active,swap;wire [1:0] ab;wire [5:0] gain;wire [15:0] w,h;
frame_presenter dut(clk,rst,tick,req,bufidx,16'd800,16'd600,ack,ab,active,gain,w,h,swap,2'd0,1'b0);
integer i;reg [1:0] lastbuf;reg [5:0] lastgain;
always @(posedge clk) begin
 lastbuf=ab;lastgain=gain;#1;
 if(!rst && !tick && (ab!=lastbuf || gain!=lastgain)) $fatal(1,"changed outside frame boundary");
 if(gain>32) $fatal(1,"gain range");
 if(!rst && ab!=lastbuf && gain!=0) $fatal(1,"switch was visible");
end
task frame;
 begin repeat(8) @(negedge clk);tick=1;@(negedge clk);tick=0;end
endtask
initial begin
 repeat(4) @(negedge clk);rst=0;bufidx=0;req=1;
 for(i=0;i<2;i=i+1) frame();
 if(!ack || !active || gain!=32 || ab!=0 || w!=800 || h!=600) $fatal(1,"first presentation failed");
 bufidx=1;req=0;
 for(i=0;i<11;i=i+1) frame();
 if(ack || gain!=32 || ab!=1) $fatal(1,"second presentation failed");
 $display("PASS presenter: vblank-only fade/swap/ack and buffer ownership");$finish;
end
endmodule
