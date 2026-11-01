`timescale 1ns/1ps
module tb_pcm_pause;
 reg clk=0;always #20 clk=~clk;
 reg rst=1,pause=0,rate=0,push=0;reg [23:0] sample=0;
 wire v0,v1,room0,room1;wire [23:0] l0,r0,l1,r1;wire [10:0] c0,c1;
 wav_pcm_48k reference(.clk(clk),.rst(rst),.flush(1'b0),.enable(1'b1),.rate_44100(rate),.push(push),.in_left(sample),.in_right(sample+24'd123),.room(room0),.valid(v0),.left(l0),.right(r0),.buffered(c0),.pause_playback(1'b0));
 wav_pcm_48k paused(.clk(clk),.rst(rst),.flush(1'b0),.enable(1'b1),.rate_44100(rate),.push(push),.in_left(sample),.in_right(sample+24'd123),.room(room1),.valid(v1),.left(l1),.right(r1),.buffered(c1),.pause_playback(pause));
 reg [47:0] expected[0:1023];integer n0=0,n1=0,ticks=0,mode,i,saved_rp,saved_phase,saved_state,last_tick=0,cycles=0;
 always @(posedge clk) begin
  #1;cycles=cycles+1;
  if(rst)begin n0=0;n1=0;ticks=0;last_tick=0;end
  else begin
   if(v0!==v1)$fatal(1,"pause changed 48k tick cadence");
   if(v0)begin
    if(last_tick!=0 && cycles-last_tick!=520 && cycles-last_tick!=521)$fatal(1,"invalid output cadence");
    last_tick=cycles;ticks=ticks+1;
    if(l0!=0)begin expected[n0]={l0,r0};n0=n0+1;end
   end
   if(v1)begin
    if(pause && (l1!=0 || r1!=0))$fatal(1,"pause not silent");
    if(l1!=0)begin
     if(n1>=n0 || {l1,r1}!==expected[n1])$fatal(1,"sample sequence changed mode=%d n=%d got=%h ref=%h",mode,n1,{l1,r1},expected[n1]);
     n1=n1+1;
    end
   end
  end
 end
 initial begin
  for(mode=0;mode<2;mode=mode+1)begin
   rst=1;pause=0;rate=mode;push=0;repeat(6)@(negedge clk);rst=0;
   for(i=0;i<900;i=i+1)begin push=1;sample=(i+1)*8192;@(negedge clk);end push=0;
   wait(n1==100);@(negedge clk);pause=1;
   saved_rp=paused.rp;saved_phase=paused.phase;saved_state=paused.state;
   repeat(60000)@(negedge clk);
   if(paused.rp!=saved_rp || paused.phase!=saved_phase || paused.state!=saved_state)$fatal(1,"playback position advanced while paused");
   pause=0;wait(n1==400);@(negedge clk);
   $display("PASS PCM pause mode=%d: 400 sample pairs exactly match uninterrupted reference, held resample phase/read pointer, silence with continuous 48 kHz ticks",mode);
  end
  $finish;
 end
 initial begin #100000000;$fatal(1,"PCM pause timeout");end
endmodule
