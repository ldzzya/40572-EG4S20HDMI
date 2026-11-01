`timescale 1ns/1ps
// Functional model for the controller's observed MRS: sequential BL4, CL3.
// Models commands, bank/row addressing, burst data and auto-precharge.
// Deliberately not an electrical SDRAM timing/compliance model.
module sdram_model(input clk,ras,cas,we,input [1:0] ba,input [10:0] addr,
 input [3:0] dm,inout [31:0] dq);
 reg [31:0] memory[0:2097151];
 reg [10:0] rows[0:3];reg [3:0] open=0;
 reg [20:0] waddr,raddr;reg [7:0] wcol,rcol;
 reg [1:0] wbank,rbank;integer wleft=0,j,k,cycle=0;
 reg [7:0] qvalid=0;reg [31:0] qdata[0:7];reg [7:0] burstcol;
 reg drive=0;reg [31:0] data=0;
 integer nwrite=0,nread=0,nrefresh=0;
 assign dq=drive ? data : 32'bz;
 function [20:0] mapped(input [10:0] row,input [1:0] bank,input [7:0] col);
  mapped={row,col[7:2],bank,col[1:0]};
 endfunction
 task put(input [20:0] a);begin
  if((^dq)===1'bx)$fatal(1,"SDRAM write data not driven address=%d data=%h word=%d",a,dq,nwrite);
  for(j=0;j<4;j=j+1)if(!dm[j])memory[a][j*8+:8]=dq[j*8+:8];
  nwrite=nwrite+1;
 end endtask
 always @(posedge clk)begin
  drive<=#5 0;
  if(wleft>0)begin
   wcol={wcol[7:2],wcol[1:0]+2'd1};put(mapped(rows[wbank],wbank,wcol));wleft=wleft-1;
  end
  if(qvalid[cycle%8])begin
   data<=#5 qdata[cycle%8];drive<=#5 1;
   qvalid[cycle%8]=0;nread=nread+1;
  end
  case({ras,cas,we})
   3'b000:begin if(addr!==11'h032 && $time>1000)$fatal(1,"unexpected MRS %h",addr);end
   3'b011:begin rows[ba]=addr;open[ba]=1;end
   3'b010:begin if(addr[10])open=0;else open[ba]=0;end
   3'b001:begin nrefresh=nrefresh+1;end
   3'b100:begin
    if(!open[ba])$fatal(1,"write without activate");
    if(wleft)$fatal(1,"overlapping SDRAM writes");
    wbank=ba;wcol=addr[7:0];put(mapped(rows[ba],ba,wcol));wleft=3;
    if(addr[10])open[ba]=0;
   end
   3'b101:begin
    if(!open[ba])$fatal(1,"read without activate");
    if(wleft)$fatal(1,"overlapping SDRAM read/write");
    for(k=0;k<4;k=k+1)begin
     burstcol={addr[7:2],addr[1:0]+k[1:0]};
     if(qvalid[(cycle+3+k)%8])$fatal(1,"overlapping SDRAM read responses");
     qdata[(cycle+3+k)%8]=memory[mapped(rows[ba],ba,burstcol)];qvalid[(cycle+3+k)%8]=1;
    end
    if(addr[10])open[ba]=0;
   end
  endcase
  cycle=cycle+1;
 end
endmodule
