`timescale 1ns/1ps
module tb_fat_media;
 reg clk=0;always #20 clk=~clk;reg rst=1;
 wire mounted,fat_ok;wire [2:0] count;reg [1:0] index=0;
 wire [31:0] bc,bs,wc,ws,fat_lba,data_lba,max_cluster;wire [2:0] shift;
 wire [2:0] req,valid,done;wire [95:0] addr;wire [7:0] data;
 wire sd_req;wire [31:0] sd_addr;reg [7:0] sd_data;reg sd_valid=0,sd_done=0;
 fat32_catalog cat(clk,rst,1'b1,index,mounted,fat_ok,count,bc,bs,wc,ws,fat_lba,data_lba,max_cluster,shift,
  req[0],addr[31:0],data,valid[0],done[0],,,,,);
 reg b_req=0,a_req=0;reg [31:0] b_sector=0,a_sector=0;wire [7:0] bd,ad;wire bv,be,av,ae;
 fat_file_sector bmp(clk,rst,1'b1,fat_lba,data_lba,max_cluster,shift,32'd100,32'd1536,b_req,b_sector,bd,bv,be,
  req[1],addr[63:32],data,valid[1],done[1]);
 fat_file_sector wav(clk,rst,1'b1,fat_lba,data_lba,max_cluster,shift,32'd200,32'd1024,a_req,a_sector,ad,av,ae,
  req[2],addr[95:64],data,valid[2],done[2]);
 media_sector_arbiter arb(clk,rst,req,addr,data,valid,done,sd_req,sd_addr,sd_data,sd_valid,sd_done);
 reg [7:0] disk[0:460799];reg [7:0] mbr[0:511];integer base=0,idx=0,delay_count=0,byte_count=0;
 integer mode,i,j,a,offset,br_count=0,ar_count=0,expected_b,expected_a;reg busy=0;
 always @(posedge clk) begin
  sd_valid<=0;sd_done<=0;
  if(rst) busy<=0;
  else if(!busy && sd_req) begin idx<=sd_addr;busy<=1;delay_count<=43;byte_count<=0;end
  else if(busy) begin
   if(delay_count!=0) delay_count<=delay_count-1;
   else if(byte_count<512) begin
    sd_data<=base!=0 && idx==0 ? mbr[byte_count] : disk[(idx-base)*512+byte_count];
    sd_valid<=1;byte_count<=byte_count+1;
   end else begin sd_done<=1;busy<=0;end
  end
 end
 always @(negedge clk) begin
  if(bv) begin
   b_req=0;
   if(bd!==((expected_b*7+br_count)&255)) $fatal(1,"BMP fragmented read byte %0d got %0d",br_count,bd);
   br_count=br_count+1;
  end
  if(av) begin
   a_req=0;
   if(ad!==((expected_a*7+ar_count)&255)) $fatal(1,"WAV fragmented read byte %0d",ar_count);
   ar_count=ar_count+1;
  end
 end
 task le32(input integer p,input integer v);begin disk[p]=v;disk[p+1]=v>>8;disk[p+2]=v>>16;disk[p+3]=v>>24;end endtask
 task le16(input integer p,input integer v);begin disk[p]=v;disk[p+1]=v>>8;end endtask
 task entry(input integer sector,input integer n,input [87:0] name,input integer cluster,input integer len);
  integer k,t;begin t=sector*512+n*32;for(k=0;k<11;k=k+1) disk[t+k]=name[(10-k)*8+:8];
   disk[t+11]=32;le16(t+20,cluster>>16);le16(t+26,cluster);le32(t+28,len);end
 endtask
 task read_b(input integer sector,input integer physical_cluster);
  begin @(negedge clk);b_sector=sector;expected_b=physical_cluster;br_count=0;b_req=1;
   wait(be);@(negedge clk);if(br_count!=512) $fatal(1,"BMP count %0d",br_count);repeat(5) @(negedge clk);end
 endtask
 initial begin
  for(i=0;i<460800;i=i+1) disk[i]=0;
  for(i=0;i<512;i=i+1) mbr[i]=0;
  le16(11,512);disk[13]=1;le16(14,32);disk[16]=1;le32(32,70632);le32(36,600);le32(44,2);le16(510,16'haa55);
  le32(32*512+2*4,9);le32(32*512+9*4,32'h0fffffff);
  le32(32*512+100*4,5);le32(32*512+5*4,250);le32(32*512+250*4,32'h0fffffff);
  le32(32*512+200*4,201);le32(32*512+201*4,32'h0fffffff);
  for(i=0;i<16;i=i+1) disk[632*512+i*32]=8'he5;
  entry(632,1,"17      BMP",100,1536);entry(632,9,"3       BMP",101,512);
  entry(639,0,"3       WAV",202,512);entry(639,1,"00017   WAV",200,1024);
  for(i=0;i<5;i=i+1) begin
   case(i) 0:a=100;1:a=5;2:a=250;3:a=200;4:a=201;endcase
   for(j=0;j<512;j=j+1) disk[(632+a-2)*512+j]=(a*7+j)&255;
  end
  mbr[450]=8'h0c;mbr[455]=8'h08;mbr[510]=8'h55;mbr[511]=8'haa;
  for(mode=0;mode<2;mode=mode+1) begin
   rst=1;base=mode==0 ? 0 : 2048;index=0;repeat(5) @(negedge clk);rst=0;
   wait(mounted);@(negedge clk);
   if(!fat_ok || count!=2 || bc!=100 || bs!=1536 || wc!=200 || ws!=1024 || fat_lba!=base+32 || data_lba!=base+632)
    $fatal(1,"catalogue mismatch mode=%0d fat=%b count=%0d bmp=%0d wav=%0d",mode,fat_ok,count,bc,wc);
   index=1;@(negedge clk);if(bc!=101 || wc!=202) $fatal(1,"numeric pairing mismatch");
   // Simultaneous file requests, audio first; responses must never cross.
   b_sector=0;a_sector=0;expected_b=100;expected_a=200;br_count=0;ar_count=0;b_req=1;a_req=1;
   wait(ae);if(br_count!=0 || ar_count!=512) $fatal(1,"audio priority or ownership");
   wait(be);@(negedge clk);if(br_count!=512) $fatal(1,"BMP lost after audio");
   read_b(1,5);read_b(2,250);read_b(1,5);read_b(0,100);
   @(negedge clk);a_sector=1;expected_a=201;ar_count=0;a_req=1;wait(ae);@(negedge clk);
   if(ar_count!=512) $fatal(1,"audio FAT cursor");
   // EOF must return an empty completion instead of reading outside the file.
   @(negedge clk);b_sector=3;br_count=0;b_req=1;wait(be);@(negedge clk);b_req=0;
   if(br_count!=0) $fatal(1,"out-of-file read");
   $display("PASS FAT32 mode %0d: numeric pairing, fragmented root/files, backward seeks, audio priority, EOF",mode);
  end
  $finish;
 end
 initial begin #100000000;$fatal(1,"timeout state=%0d",cat.state);end
endmodule
