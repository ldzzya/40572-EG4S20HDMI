`timescale 1ns/1ps
module tb_controls;
reg clk=0,rst=1,button=1,up=0,down=0,iv=0;always #20 clk=~clk;
wire short_n,lp,ov;wire signed [23:0] ol,orr;wire [4:0] level;
reg signed [23:0] il=24'sd2000000,ir=-24'sd2000000;
key_gesture #(.DEBOUNCE_CYCLES(4),.HOLD_CYCLES(24),.REPEAT_CYCLES(12),.SHORT_CYCLES(8))
 key_test(clk,rst,button,short_n,lp);
audio_volume gain_test(clk,rst,down,up,iv,il,ir,ov,ol,orr,level,1'b0);
integer shorts=0,longs=0,i,sb,lb;reg last_short=1;
always @(negedge clk) begin
 if(!short_n && last_short) shorts=shorts+1;
 if(lp) longs=longs+1;
 last_short=short_n;
end
task samples(input integer n);
 integer j;begin for(j=0;j<n;j=j+1) begin
  iv=1;@(negedge clk);if(!ov) $fatal(1,"PCM valid lost");
  iv=0;@(negedge clk);if(ov) $fatal(1,"extra PCM sample");
 end end
endtask
task step_down;begin down=1;@(negedge clk);down=0;@(negedge clk);end endtask
initial begin
 repeat(8) @(negedge clk);rst=0;
 // Bounce must not trigger either gesture.
 repeat(3) begin button=0;@(negedge clk);button=1;repeat(2) @(negedge clk);end
 repeat(10) @(negedge clk);
 if(shorts || longs) $fatal(1,"button bounce action");
 button=0;repeat(15) @(negedge clk);button=1;repeat(20) @(negedge clk);
 if(shorts!=1 || longs!=0) $fatal(1,"short-release classification");
 button=0;repeat(75) @(negedge clk);button=1;repeat(22) @(negedge clk);
 if(shorts!=1 || longs<4) $fatal(1,"hold repeated or release created a short action");
 // Sweep the exact short/long boundary, including debounce release at expiry.
 for(i=21;i<40;i=i+1) begin
  sb=shorts;lb=longs;button=0;repeat(i) @(negedge clk);button=1;repeat(30) @(negedge clk);
  if(shorts>sb && longs>lb) $fatal(1,"short and long both fired at boundary duration %0d",i);
 end
 samples(260);
 if(level!=20 || ol!=il || orr!=ir) $fatal(1,"unity gain/stereo failed");
 for(i=0;i<10;i=i+1) step_down();samples(140);
 if(level!=10 || ol!=1000000 || orr!=-1000000) $fatal(1,"50 percent gain/stereo failed %d %d",ol,orr);
 for(i=0;i<15;i=i+1) step_down();samples(140);
 if(level!=0 || ol!=0 || orr!=0) $fatal(1,"mute or lower clamp failed");
 up=1;down=1;repeat(5) @(negedge clk);up=0;down=0;
 if(level!=0) $fatal(1,"opposite controls should cancel");
 up=1;repeat(25) @(negedge clk);up=0;samples(260);
 if(level!=20) $fatal(1,"upper clamp failed");
 il=-24'sd8388608;ir=24'sd8388607;samples(3);
 if(ol!=il || orr!=ir) $fatal(1,"full-scale signed arithmetic overflow");
 rst=1;@(negedge clk);
 if(ov || ol || orr) $fatal(1,"reset audio not silent");
 $display("PASS controls: debounce, short/hold separation, hold repeat, 100/50/0 percent stereo gain, signed endpoints, clamps and reset");$finish;
end
endmodule
