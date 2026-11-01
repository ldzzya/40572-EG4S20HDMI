`timescale 1ns/1ps
module tb_audio_bars;
 reg clk=0;always #5 clk=~clk;reg rst=1,frame=0,av=0,down=0,mute=0;
 reg [23:0] pcm_l=0,pcm_r=0;wire ov;wire [23:0] ol,orr;wire [4:0] volume;
 reg [4:0] read_index=0;wire [6:0] height;
 audio_volume gain(.clk(clk),.rst(rst),.down(down),.up(1'b0),.mute(mute),.in_valid(av),
  .in_left(pcm_l),.in_right(pcm_r),.out_valid(ov),.out_left(ol),.out_right(orr),.level(volume));
 audio_bars dut(clk,rst,frame,ov,ol,orr,mute,read_index,height);
 integer sample=0,i,j,f,k,fullsum,halfsum,maxlow,maxhigh,lowindex,highindex,prev;
 integer amplitude=1048576,frequency=100;reg right_only=0;
 task audio_frame;
  begin
   for(k=0;k<800;k=k+1) begin
    pcm_l=right_only ? 0 : $rtoi(amplitude*$sin(6.283185307179586*frequency*sample/48000.0));
    pcm_r=right_only ? $rtoi(amplitude*$sin(6.283185307179586*frequency*sample/48000.0)) : pcm_l;
    av=1;@(negedge clk);av=0;repeat(519) @(negedge clk);sample=sample+1;
   end
   frame=1;@(negedge clk);frame=0;repeat(220) @(negedge clk);
  end
 endtask
 always @(posedge clk) if(!rst && ov && dut.audio_pending) $fatal(1,"filter misses an audio sample");
 initial begin
  repeat(4) @(negedge clk);rst=0;
  for(f=0;f<6;f=f+1) audio_frame();
  fullsum=0;maxlow=0;lowindex=0;
  for(i=0;i<24;i=i+1) begin
   fullsum=fullsum+dut.display[i];if(dut.display[i]>maxlow)begin maxlow=dut.display[i];lowindex=i/2;end
   if(dut.display[i]>104) $fatal(1,"bar exceeds height budget");
  end
  if(maxlow<35) $fatal(1,"quiet music not visible enough %d",maxlow);
  // Display values must stay fixed between video frames.
  prev=dut.display[0];repeat(900) @(negedge clk);if(dut.display[0]!=prev) $fatal(1,"mid-frame tearing");
  for(i=0;i<10;i=i+1)begin down=1;@(negedge clk);down=0;@(negedge clk);end
  for(f=0;f<10;f=f+1) audio_frame();
  halfsum=0;for(i=0;i<24;i=i+1)halfsum=halfsum+dut.display[i];
  if(halfsum>=fullsum-10 || halfsum==0) $fatal(1,"volume ignored %d %d",fullsum,halfsum);
  frequency=4000;for(f=0;f<10;f=f+1) audio_frame();maxhigh=0;highindex=0;
  for(i=0;i<24;i=i+1)if(dut.display[i]>maxhigh)begin maxhigh=dut.display[i];highindex=i/2;end
  if(highindex<=lowindex+3) $fatal(1,"frequency bands do not follow pitch %d %d",lowindex,highindex);
  right_only=1;for(f=0;f<27;f=f+1) audio_frame();
  for(i=0;i<24;i=i+2) if(dut.display[i]>1) $fatal(1,"silent left channel shows right channel audio");
  if(dut.display[highindex*2+1]<10) $fatal(1,"right-only audio invisible");
  mute=1;audio_frame();for(i=0;i<24;i=i+1)if(dut.display[i]!=0)$fatal(1,"mute leaves a bar");
  $display("PASS bars: volume totals %0d/%0d, pitch bands %0d/%0d, independent stereo, frame latch, height <=104 and mute",fullsum,halfsum,lowindex,highindex);$finish;
 end
 initial begin #1200000000;$fatal(1,"timeout");end
endmodule
