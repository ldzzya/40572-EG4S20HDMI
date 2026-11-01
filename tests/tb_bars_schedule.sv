`timescale 1ns/1ps
module tb_bars_schedule;
 reg clk=0; always #5 clk=~clk;
 reg rst=1,frame=0,av=0; wire [6:0] height;
 audio_bars dut(clk,rst,frame,av,24'd1048576,24'd2097152,1'b0,5'd0,height);
 integer phase,t;
 initial begin
  repeat(4) @(negedge clk);rst=0;repeat(260) @(negedge clk);
  // Sweep every relative phase, including a frame sweep immediately before
  // the next PCM tick. One 48 kHz period is at least 520 pixel clocks.
  for(phase=0;phase<520;phase=phase+1) begin
   for(t=0;t<520;t=t+1) begin
    av=(t==0);frame=(t==phase);@(negedge clk);
   end
   av=0;frame=0;
  end
  repeat(220) @(negedge clk);
  if(dut.state!=0 || dut.audio_pending || dut.frame_pending) $fatal(1,"scheduler failed to drain");
  $display("PASS bars scheduling: all 520 frame/audio phase offsets, no unfinished audio at next sample");$finish;
 end
 always @(posedge clk) if(!rst && av && (dut.audio_pending || (dut.state>=1 && dut.state<=6)))
  $fatal(1,"PCM overwritten before previous sample completed");
endmodule
