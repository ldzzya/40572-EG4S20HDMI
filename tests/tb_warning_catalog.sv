`timescale 1ns/1ps
module tb_warning_catalog;
 reg clk=0;always #10 clk=~clk;reg rst=1;reg [2:0] index=0;
 wire mounted,ok,pfound,req;wire [2:0] pi,count,shift;
 wire [31:0] bc,bs,wc,ws,fl,dl,mc,addr;reg [7:0] data=0;reg valid=0,done=0;
 fat32_catalog dut(.clk(clk),.rst(rst),.card_ready(1'b1),.index(index),.mounted(mounted),.fat_ok(ok),
  .image_count(count),.bmp_cluster(bc),.bmp_size(bs),.wav_cluster(wc),.wav_size(ws),
  .fat_lba(fl),.data_lba(dl),.max_cluster(mc),.cluster_shift(shift),.disk_req(req),.disk_addr(addr),
  .disk_data(data),.disk_valid(valid),.disk_done(done),.priority_found(pfound),.priority_index(pi));
 reg [7:0] disk[0:460799];integer i,j,pos=0,lba=0,mode;reg busy=0;
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
  for(mode=0;mode<5;mode=mode+1)begin
   rst=1;repeat(4)@(negedge clk);
   for(i=0;i<460800;i=i+1)disk[i]=0;
   le16(11,512);disk[13]=1;le16(14,32);disk[16]=1;le32(32,70632);le32(36,600);le32(44,2);le16(510,16'haa55);
   le32(32*512+8,9);le32(32*512+36,32'h0fffffff);
   for(i=0;i<16;i=i+1)disk[632*512+i*32]=8'he5;
   ent(632,0,"WARNING PNG",99);ent(632,1,"OTHER   BMP",98);
   ent(632,2,"WARNING1BMP",97);ent(632,3,"1       JPG",96);
   ent(632,4,"1X      BMP",95);ent(632,5,"WARNIN~1BMP",94);
   if(mode!=3)begin
    ent(632,6,"1       BMP",10);ent(632,7,"00000001BMP",90);
    ent(632,8,"2       bMp",20);ent(632,9,"3       BMP",30);
    ent(632,10,"4       BMP",40);ent(632,11,"5       BMP",50);
    ent(639,0,"4       WAV",140);ent(639,1,"1       WaV",110);
    ent(639,2,"2       WAV",120);ent(639,3,"3       WAV",130);
   end
   if(mode==1)ent(632,0,"WARNING BMP",70);
   if(mode==2 || mode==3)ent(639,4,"warning bmp",70);
   if(mode==4)ent(632,5,"WaRnInG bMp",70);
   // WAV appears before or after its BMP; casing is independent.
   ent(632,12,"Warning wAv",170);
   if(mode==3)begin
    for(i=0;i<4;i=i+1)disk[639*512+i*32]=8'he5;
   end
   rst=0;wait(mounted);@(negedge clk);
   if(!ok || count!=(mode==3 ? 0 : 4) || pfound!=(mode!=0) || pi!=4)
    $fatal(1,"catalogue separation failed mode=%0d count=%0d found=%0d",mode,count,pfound);
   if(mode!=3)for(j=0;j<4;j=j+1)begin
    index=j;@(negedge clk);
    if(bc!=(j+1)*10 || wc!=(j+1)*10+100)$fatal(1,"numeric pair %0d changed %0d/%0d",j,bc,wc);
   end
   index=4;@(negedge clk);
   if((pfound && bc!=70) || wc!=170)$fatal(1,"warning pair not independent");
   index=7;@(negedge clk);if(bc!=0 || wc!=0)$fatal(1,"invalid catalogue index");
   $display("PASS warning catalogue %0d: numeric-only, duplicate handling, independent fifth slot, mixed case and fragmented root",mode);$fflush();
  end
  $finish;
 end
 initial begin #10000000;$fatal(1,"catalogue timeout");end
endmodule
