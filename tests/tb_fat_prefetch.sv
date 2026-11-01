`timescale 1ns/1ps
module fat_test_disk(input clk,rst,input fragmented,input req,input [31:0] addr,output reg [7:0] data,output reg valid,done,output reg [15:0] reads);
 integer n,delay_count;reg busy;reg [31:0] latched,link;
 always @(posedge clk) begin
 valid<=0;done<=0;
 if(rst)begin busy<=0;reads<=0;end
 else if(!busy && req)begin busy<=1;latched<=addr;n<=0;delay_count<=20;reads<=reads+1;end
 else if(busy)begin
 if(delay_count!=0)delay_count<=delay_count-1;
 else if(n<512)begin
 if(latched<1000)begin link=(latched-32)*128+n/4+(fragmented ? 3 : 1);data<=link>>((n%4)*8);end
 else data<=(latched-1000+2+n)&255;
 valid<=1;n<=n+1;
 end else begin done<=1;busy<=0;end
 end
 end
endmodule
module tb_fat_prefetch;
 reg clk=0,rst=1,fragmented=0;always #20 clk=~clk;
 reg [1:0] req=0;reg [31:0] sector=0;
 wire [1:0] v,done,dr,dv,dd;wire [7:0] b[0:1],db[0:1];wire [31:0] da[0:1];wire [15:0] reads[0:1];
 genvar g;generate for(g=0;g<2;g=g+1)begin:G
 fat_file_sector #(.PREFETCH_NEXT(g)) dut(clk,rst,1'b1,32'd32,32'd1000,32'd5000,3'd0,32'd124,32'd8192,req[g],sector,b[g],v[g],done[g],dr[g],da[g],db[g],dv[g],dd[g]);
 fat_test_disk disk(clk,rst,fragmented,dr[g],da[g],db[g],dv[g],dd[g],reads[g]);
 end endgenerate
 integer count[0:1],mode,s,k,cycles=0;integer start_cycle,end_cycle[0:1];reg [1:0] finished=0;
 always @(negedge clk)begin
 cycles=cycles+1;
 if(!rst) for(k=0;k<2;k=k+1)begin
 if(v[k])begin req[k]=0;if(b[k]!==((124+sector*(fragmented ? 3 : 1)+count[k])&255))$fatal(1,"data mismatch %0d %0d",k,sector);count[k]=count[k]+1;end
 if(done[k])begin finished[k]=1;end_cycle[k]=cycles;end
 end
 end
 initial begin
 for(mode=0;mode<2;mode=mode+1)begin
 rst=1;fragmented=mode;repeat(5)@(negedge clk);rst=0;start_cycle=cycles;
 for(s=0;s<16;s=s+1)begin
 @(negedge clk);sector=s;count[0]=0;count[1]=0;finished=0;req=3;
 wait(finished==3);@(negedge clk);
 if(count[0]!=512 || count[1]!=512)$fatal(1,"short sector");repeat(5)@(negedge clk);
 end
 if(mode==0 && !(reads[1]<reads[0] && reads[1]<=25))$fatal(1,"prefetch no gain");
 if(mode==1 && reads[1]!=reads[0])$fatal(1,"fragment chain skipped");
 $display("PASS FAT prefetch fragmented=%0d baseline_reads=%0d optimized_reads=%0d, identical 8192 bytes including FAT-sector boundary",mode,reads[0],reads[1]);
 end
 $finish;
 end
 initial begin #10000000;$fatal(1,"timeout");end
endmodule
