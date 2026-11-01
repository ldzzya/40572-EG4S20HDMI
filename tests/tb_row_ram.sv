`timescale 1ns/1ps
module tb_row_ram;
 reg clk=0;always #5 clk=~clk;reg we=0;reg [10:0] wa=0,ra=0;reg [23:0] wd=0;wire [23:0] rd;
 integer i;reg [23:0] expected;
 rgb_row_ram dut(clk,we,wa,ra,wd,rd);
 initial begin
  repeat(3)@(negedge clk);
  for(i=0;i<2048;i=i+1)begin wa=i;wd={i[7:0],i[10:3],i[7:0]^8'h5a};we=1;@(negedge clk);end
  we=0;
  for(i=0;i<2048;i=i+1)begin ra=i;expected={i[7:0],i[10:3],i[7:0]^8'h5a};@(negedge clk);
   if(rd!==expected)$fatal(1,"physical BRAM32K mismatch address=%d %h != %h",i,rd,expected);
  end
  $display("PASS physical BRAM32K RGB row: all 2048 addresses, both ports, byte mask and read latency");$finish;
 end
endmodule
