`timescale 1ns/1ps
module tb_audio;
reg clk=0;always #20 clk=~clk;
reg rst=1;wire valid;wire [23:0] l,r;wire av;wire [19:0] cts,n;
tone_pcm_48k dut(clk,rst,valid,l,r);
audio_arc_calculate acr(clk,rst,valid,av,cts,n);
integer cycles=0,samples=0,acrs=0,last=0,spacing;reg nonzero=0;
always @(negedge clk) if(!rst) begin
 cycles=cycles+1;
 if(valid) begin
  spacing=cycles-last;last=cycles;samples=samples+1;
  if(spacing!=520 && spacing!=521) $fatal(1,"sample spacing %0d",spacing);
  if(l!==r) $fatal(1,"stereo mismatch");
  if(l!=0) nonzero=1;
 end
 if(av) begin
  acrs=acrs+1;
  if(acrs>1 && (cts!=25000 || n!=6144)) $fatal(1,"ACR %0d %0d",cts,n);
 end
 if(cycles==2500000) begin
  if(samples!=4800 || !nonzero || acrs<99) $fatal(1,"audio count %0d",samples);
  $display("PASS audio: 4800 samples / 100 ms, stereo PCM, CTS=25000 N=6144");$finish;
 end
end
initial begin repeat(10) @(negedge clk);#1;rst=0;end
endmodule
