`timescale 1ns/1ps
module tb_layer_720;
 reg clk=0;always #5 clk=~clk;
 reg rst=1,lr=0,le=0,we=0,show=0,vs=0,de=0;reg [7:0] wm=0;
 reg [9:0] top=216;reg [23:0] rgb=24'h5372a4;
 wire ovs,ode;wire [23:0] orgb;wire [7:0] mask;
 integer x,y,pass;reg [7:0] expected;
 warning_layer_cache dut(clk,rst,lr,le,we,wm,top,show,vs,de,rgb,ovs,ode,orgb,mask);
 function [7:0] sample(input integer x,input integer y);
  sample=(x>=102 && x<1182 && y>=top && y<top+76)?(((x/2+y/2)%63)<<2)|3:0;
 endfunction
 initial begin
  repeat(8)@(negedge clk);rst=0;
  for(pass=0;pass<2;pass=pass+1)begin
   // Reload a moved banner: zero-alpha positions must overwrite stale pixels.
   top=pass==0 ? 216:40;le=1;lr=1;repeat(3)@(negedge clk);lr=0;
   for(y=719;y>=0;y=y-1)for(x=0;x<1280;x=x+1)begin
    we=1;wm=sample(x,y);@(negedge clk);
   end
   we=0;le=0;repeat(3)@(negedge clk);show=1;vs=1;@(negedge clk);vs=0;
   for(y=0;y<720;y=y+1)begin
    for(x=0;x<1280;x=x+1)begin
     de=1;expected=sample(x,y);@(posedge clk);#1;
     if(!ode || orgb!==rgb || mask!==expected)$fatal(1,"mask misaligned (%d,%d): %h want %h",x,y,mask,expected);
     @(negedge clk);
    end
    de=0;repeat(8)@(negedge clk);
   end
   show=0;@(posedge clk);#1;if(mask!==0)$fatal(1,"mask leaked outside warning");
   @(negedge clk);
  end
  $display("PASS warning720: bottom-up capture, full-width cache banks, transparent pixels, independent background, moved banner and normal-mode isolation");$finish;
 end
 initial begin #100000000;$fatal(1,"layer timeout");end
endmodule
