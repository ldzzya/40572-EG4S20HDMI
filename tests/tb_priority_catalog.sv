`timescale 1ns/1ps
module tb_priority_catalog;
 reg clk=0;always #10 clk=~clk;reg rst=1;reg [1:0] index=0;
 wire mounted,ok,pfound,req;wire [1:0] pi;wire [2:0] count,shift;
 wire [31:0] bc,bs,wc,ws,fl,dl,mc,addr;reg [7:0] data=0;reg valid=0,done=0;
 fat32_catalog dut(clk,rst,1'b1,index,mounted,ok,count,bc,bs,wc,ws,fl,dl,mc,shift,req,addr,data,valid,done,pfound,pi,,,);
 reg [7:0] disk[0:460799];integer i,j,p,k,pos=0,lba=0,mode;reg busy=0;
 task le32(input integer p,input integer v);begin disk[p]=v;disk[p+1]=v>>8;disk[p+2]=v>>16;disk[p+3]=v>>24;end endtask
 task le16(input integer p,input integer v);begin disk[p]=v;disk[p+1]=v>>8;end endtask
 task ent(input integer sector,input integer slot,input [87:0] name,input integer cl);
  integer a,q;begin a=sector*512+slot*32;for(q=0;q<11;q=q+1)disk[a+q]=name[(10-q)*8+:8];disk[a+11]=32;le16(a+26,cl);le32(a+28,512);end
 endtask
 always @(posedge clk)begin
  valid<=0;done<=0;
  if(rst)busy<=0;
  else if(!busy && req)begin busy<=1;pos<=0;lba<=addr;end
  else if(busy)begin
   if(pos<512)begin data<=disk[lba*512+pos];valid<=1;pos<=pos+1;end
   else begin done<=1;busy<=0;end
  end
 end
 initial begin
  for(mode=0;mode<3;mode=mode+1)begin
   rst=1;repeat(4)@(negedge clk);
   for(i=0;i<460800;i=i+1)disk[i]=0;
   le16(11,512);disk[13]=1;le16(14,32);disk[16]=1;le32(32,70632);le32(36,600);le32(44,2);le16(510,16'haa55);
   le32(32*512+8,9);le32(32*512+36,32'h0fffffff);
   for(i=0;i<16;i=i+1)disk[632*512+i*32]=8'he5;
   ent(632,0,"2       BMP",20);ent(632,1,"3       BMP",30);ent(632,2,"4       BMP",40);ent(632,3,"5       BMP",50);
   ent(639,0,"1       WAV",110);
   if(mode==1)ent(632,2,"1       BMP",10);
   if(mode==2)ent(639,1,"1       BMP",10);
   rst=0;wait(mounted);@(negedge clk);
   if(!ok || count!=4 || pfound!=(mode!=0))$fatal(1,"catalogue priority presence");
   if(mode!=0)begin index=pi;@(negedge clk);
    if(bc!=10 || wc!=110 || pi!=(mode==1 ? 2 : 3))$fatal(1,"numeric priority index/matching");
   end
   $display("PASS priority catalogue case %d: missing / in first four / beyond first four and fragmented root",mode);
  end
  $finish;
 end
 initial begin #10000000;$fatal(1,"catalogue timeout");end
endmodule
