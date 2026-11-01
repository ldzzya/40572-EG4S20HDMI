`timescale 1ns/1ps
module tb_transition;
reg clk=0,rst=1,tick=0,req=0;always #5 clk=~clk;
reg [1:0] bufidx=0,mode=2;wire ack,active,swap;wire [1:0] bufout;wire [5:0] gain;wire [15:0] w,h;
frame_presenter #(.FADE_STEP(2)) dut(clk,rst,tick,req,bufidx,16'd1280,16'd720,ack,bufout,active,gain,w,h,swap,mode,1'b0);
task frame;begin repeat(6) @(negedge clk);tick=1;@(negedge clk);tick=0;@(negedge clk);end endtask
integer n;reg [1:0] prev_buf;reg [5:0] prev_gain;
always @(posedge clk) begin prev_buf=bufout;prev_gain=gain;#1;if(!rst && !tick && (bufout!=prev_buf || gain!=prev_gain)) $fatal(1,"transition outside vblank");end
initial begin
 repeat(4) @(negedge clk);rst=0;req=1;frame();frame();
 if(!ack || !active || gain!=32 || bufout!=0) $fatal(1,"startup");
 bufidx=1;req=0;frame();if(ack || bufout!=1 || gain!=32) $fatal(1,"cut should swap without black frame");
 mode=1;bufidx=0;req=1;frame();
 for(n=0;n<16;n=n+1) begin frame();if(bufout!=1 || gain!=30-n*2 || ack) $fatal(1,"curtain down progression %d",n);end
 frame();if(bufout!=0 || gain!=0 || ack) $fatal(1,"curtain swap");
 for(n=0;n<16;n=n+1) frame();
 if(!ack || gain!=32) $fatal(1,"curtain final ack");
 $display("PASS transitions: direct cut without black interval, 16-step close/open, blank-only swap and retained ownership until reveal");$finish;
end
endmodule
