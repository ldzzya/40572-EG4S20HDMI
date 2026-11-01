`timescale 1ns/1ps
module tb_sector_bridge;
reg cc=0,sc=0,rst=1;always #20 cc=~cc;initial begin #3;forever #5 sc=~sc;end
reg req=0,init=0,sv=0,se=0;reg[31:0] addr=0;reg[7:0] sd=0;
wire[7:0] data;wire valid,ending,ready,sreq;wire[31:0] sa;
sd_sector_bridge dut(cc,rst,sc,rst,req,addr,data,valid,ending,ready,sreq,sa,sd,sv,se,init);
integer n,i,received=0,seed=0,transactions=0;
function[7:0] pattern(input integer index,input integer salt);
 pattern=(index*37+salt*19) ^ (index>>3);
endfunction
always @(negedge cc) begin
 if(valid) begin
  if(data!==pattern(received,seed)) $fatal(1,"byte %0d: got %h expected %h",received,data,pattern(received,seed));
  received=received+1;req=0;
 end
 if(ending && valid) $fatal(1,"end overlaps last byte");
end
task transfer(input integer count,input integer salt,input integer same_cycle_end);
begin
 @(negedge cc);received=0;seed=salt;addr=32'h120000+salt;req=1;
 wait(sreq);@(negedge sc);
 if(sa!==32'h120000+salt) $fatal(1,"address mailbox corrupt");
 repeat(7) @(negedge sc);
 for(i=0;i<count;i=i+1) begin
  sv=1;sd=pattern(i,salt);se=(same_cycle_end && i==count-1);
  @(negedge sc);sv=0;se=0;
  repeat((i%5)+1) @(negedge sc);
 end
 if(!same_cycle_end || count==0) begin se=1;@(negedge sc);se=0;end
 wait(ending);#1;req=0;
 if(received!=count) $fatal(1,"length %0d vs %0d",received,count);
 transactions=transactions+1;
 // Return at the earliest safe point for the next request.
 @(negedge cc);
end
endtask
initial begin
 repeat(4) @(negedge cc);rst=0;
 repeat(4) @(negedge sc);init=1;wait(ready);
 transfer(512,1,0);transfer(512,2,1);transfer(511,3,0);
 transfer(0,4,0);transfer(1,5,1);transfer(512,6,1);
 @(negedge cc);rst=1;repeat(4) @(negedge cc);rst=0;wait(ready);
 transfer(512,7,0);
 $display("PASS sector_bridge: %0d asynchronous transactions, full/short/empty sectors, coincident end, reset and exact byte order",transactions);$finish;
end
initial begin #2000000;$fatal(1,"bridge timeout");end
endmodule
