`timescale 1ns/1ps
module tb_packing_720;
 reg clk=0;always #6.734 clk=~clk;
 reg rst=1,pv=0,pr=0;reg [23:0] pd;
 wire wv,re,underflow;wire [31:0] wd;wire [23:0] out;
 reg [31:0] words[0:691199];reg [31:0] q;
 integer wp=0,rp=0,pixels=0,x,y,i,pass;
 function [23:0] pattern(input integer p);
  pattern=((p*65537)^(p>>5)^24'hbc9876)&24'hffffff;
 endfunction
 rgb24_pack packer(clk,rst,pv,pd,wv,wd);
 rgb24_unpack unpacker(clk,rst,rp>=wp,re,q,pr,out,underflow);
 always @(posedge clk)begin
  if(rst)begin wp<=0;rp<=0;end
  else begin
   if(wv)begin words[wp]<=wd;wp<=wp+1;end
   if(re)begin q<=words[rp];rp<=rp+1;end
  end
 end
 initial begin
  for(pass=0;pass<2;pass=pass+1)begin
   rst=1;pv=0;pr=0;repeat(8)@(negedge clk);rst=0;
   for(i=0;i<921600;i=i+1)begin
    @(negedge clk);pv=1;pd=pattern(i);
    if(i%19==0)begin @(negedge clk);pv=0;end
   end
   @(negedge clk);pv=0;repeat(15)@(negedge clk);
   if(wp!=691200)$fatal(1,"wrong packed word count %d",wp);
   pixels=0;
   for(y=0;y<720;y=y+1)begin
    for(x=0;x<1280;x=x+1)begin
     pr=1;@(posedge clk);#1;
     if(out!==pattern(pixels))$fatal(1,"RGB packing mismatch %d: %h expected %h",pixels,out,pattern(pixels));
     pixels=pixels+1;@(negedge clk);
    end
    pr=0;repeat(370)@(negedge clk);
   end
   if(underflow || rp!=691200)$fatal(1,"FIFO overread/underflow %d",rp);
  end
  $display("PASS packed720: 2 native frames, every RGB bit, 3 words/4 pixels, 720p blanking and reset");$finish;
 end
 initial begin #100000000;$fatal(1,"packing timeout");end
endmodule
