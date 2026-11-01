`timescale 1ns/1ps
module tb_priority_media;
 reg clk=0,spi_clk=0;always #20 clk=~clk;always #5 spi_clk=~spi_clk;
 reg rst=1,key_next=1,key_auto=1,locked=0,tick=0,finish=0;
 wire req,we,commit,ack,display,active,swap;wire [31:0] pixel;wire [3:0] status,wav_status;
 wire [15:0] width,height;wire [1:0] wb,db,ab;wire [2:0] count;wire [5:0] gain;
 wire av,autoplay;wire [23:0] al,ar;
 integer cycles=0,pixels=0,frames=0,swaps=0,audio1=0,audio2=0,lastswap=0,i,heldframes;reg [1:0] audible_index=0;
 sd_card_bmp #(.CLK_FREQ_HZ(25000000),.BUTTON_EVENTS(1)) dut(.clk(clk),.rst(rst),.spi_clk(spi_clk),.spi_rst(rst),
  .priority_mode(locked),.key_next(key_next),.key_auto(key_auto),.auto_play_en(autoplay),.state_code(status),.bmp_width(16'd640),.bmp_height(16'd480),
  .display_valid(display),.commit_toggle(commit),.commit_ack(ack),.source_width(width),.source_height(height),
  .write_ready(cycles%17!=0),.write_finish_toggle(finish),.write_buf_idx(wb),.disp_buf_idx(db),
  .write_req(req),.write_req_ack(req),.write_en(we),.write_data(pixel),.SD_MISO(1'b1),
  .image_count(count),.aspect_fit(1'b0),.image_swap(swap),.wav_valid(av),.wav_left(al),.wav_right(ar),.wav_status(wav_status));
 frame_presenter #(.FADE_STEP(2)) presenter(.clk(clk),.rst(rst),.frame_tick(tick),.request_toggle(commit),
  .requested_buf(db),.source_width(width),.source_height(height),.ack_toggle(ack),.active_buf(ab),
  .display_active(active),.gain(gain),.transition(locked ? 2'd2 : 2'd0),.image_swap(swap));
 always @(posedge clk) begin
  cycles<=cycles+1;tick<=cycles%1000==0;
  if(swap) begin lastswap<=cycles;audible_index<=dut.load_index;swaps<=swaps+1;end
  if(!rst && we) begin
   if(pixel[31:8] !== (dut.load_index==1 ? 24'h123456 : 24'habcd21))$fatal(1,"priority BMP corrupted");
   if(pixels==307199)begin pixels<=0;frames<=frames+1;finish<=~finish;end else pixels<=pixels+1;
  end
  if(!rst && av && cycles-lastswap>4 && (al!=0 || ar!=0)) begin
   if(locked && !dut.priority_playing)$fatal(1,"old audio audible while priority loading");
   if(audible_index==1)begin
    if(al!==24'h010000 || ar!==24'h020000)$fatal(1,"numeric 1.wav mismatch %h %h",al,ar);
    audio1<=audio1+1;
   end else begin
    if(al!==24'hff0000 || ar!==24'h040000)$fatal(1,"numeric 2.wav mismatch %h %h",al,ar);
    audio2<=audio2+1;
   end
  end
  if(wav_status==4 || wav_status==5 || status==14)$fatal(1,"read error/underrun %d %d",status,wav_status);
 end
 task next_picture;begin key_next=0;repeat(4)@(negedge clk);key_next=1;repeat(4)@(negedge clk);end endtask
 initial begin
  repeat(8)@(negedge clk);rst=0;wait(display);wait(audio2>=200);
  if(dut.priority_index!=1)$fatal(1,"assumed directory index zero");
  // Enable automatic mode, then priority must suspend it without losing preference.
  @(negedge clk);key_auto=0;repeat(4)@(negedge clk);key_auto=1;repeat(4)@(negedge clk);
  locked=1;wait(dut.priority_playing);wait(audio1>=200);wait(dut.state==6);
  heldframes=frames;
  for(i=0;i<5;i=i+1) begin next_picture();key_auto=0;repeat(4)@(negedge clk);key_auto=1;end
  force dut.auto_count=124999999;repeat(3000)@(negedge clk);
  if(frames!=heldframes || dut.load_index!=1 || !autoplay || dut.auto_due)$fatal(1,"priority escaped by keys/auto");
  release dut.auto_count;repeat(5)@(negedge clk);locked=0;
  next_picture();wait(dut.state==5); // lock during the existing fade/commit path
  @(negedge clk);locked=1;wait(swaps>=4);wait(dut.state==6);
  if(dut.current_index!=1 || !dut.priority_playing || gain!=32)$fatal(1,"priority during transition");
  @(negedge clk);locked=0;next_picture();wait(dut.state==5);wait(dut.state==6);
  if(dut.current_index!=0)$fatal(1,"normal picture navigation not restored");
  // Interrupt an in-progress non-priority load. Finish SDRAM safely, discard
  // its commit, then load priority into the same hidden buffer.
  next_picture();wait(dut.state==6);next_picture();wait(dut.state==4'd4 && pixels>500);
  @(negedge clk);heldframes=swaps;locked=1;wait(dut.priority_playing);wait(dut.state==6);
  if(swaps!=heldframes+1 || dut.current_index!=1)$fatal(1,"non-priority in-flight frame was committed");
  // Power-on with SW1 already engaged must select numeric 1 as first frame.
  @(negedge clk);rst=1;heldframes=audio1;repeat(8)@(negedge clk);rst=0;
  wait(display);wait(audio1>heldframes+50);
  if(dut.current_index!=1 || !dut.priority_playing || gain!=32)$fatal(1,"locked boot selected another file");
  $display("PASS priority media: numeric 1 in second directory slot, matched WAV, old-track silence, locked next/auto, cut during fade, safe in-flight discard, unlock navigation, boot already locked");$finish;
 end
 initial begin #4000000000;$fatal(1,"priority pipeline timeout frames=%d state=%d",frames,dut.state);end
endmodule

module sd_card_top #(parameter SPI_LOW_SPEED_DIV=248,SPI_HIGH_SPEED_DIV=0)(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output reg sd_init_done,
 input sd_sec_read,input [31:0] sd_sec_read_addr,output reg [7:0] sd_sec_read_data,
 output reg sd_sec_read_data_valid,sd_sec_read_end,input sd_sec_write,input [31:0] sd_sec_write_addr,
 input [7:0] sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end
);
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 reg [7:0] disk[0:511999];integer i,j,t,a,k,init_count=0,waits=0,bytepos=0,addr=0;reg busy=0;
 task le32(input integer p,input integer v);begin disk[p]=v;disk[p+1]=v>>8;disk[p+2]=v>>16;disk[p+3]=v>>24;end endtask
 task le16(input integer p,input integer v);begin disk[p]=v;disk[p+1]=v>>8;end endtask
 task dirent(input integer slot,input [87:0] name,input integer cluster,input integer len);
  integer p,q;begin p=632*512+slot*32;for(q=0;q<11;q=q+1)disk[p+q]=name[(10-q)*8+:8];
   disk[p+11]=32;le16(p+26,cluster);le32(p+28,len);end
 endtask
 task bmp_file(input integer cluster,input integer w,input integer h,input [23:0] rgb);
  integer p,n,l;begin p=(630+cluster)*512;l=54+w*h*3;disk[p]="B";disk[p+1]="M";
   le32(p+2,l);le32(p+10,54);le32(p+14,40);le32(p+18,w);le32(p+22,h);le16(p+26,1);le16(p+28,24);
   for(n=0;n<w*h;n=n+1) begin disk[p+54+n*3]=rgb[7:0];disk[p+55+n*3]=rgb[15:8];disk[p+56+n*3]=rgb[23:16];end
   for(n=0;n<(l+511)/512;n=n+1) le32(32*512+(cluster+n)*4,n==(l+511)/512-1 ? 32'h0fffffff : cluster+n+1);
  end
 endtask
 task wav_file(input integer first,input [23:0] left,right);
  integer n,p,sec,cl,off;reg [7:0] value;begin
   for(n=0;n<25;n=n+1) le32(32*512+(first+n*3)*4,n==24 ? 32'h0fffffff : first+(n+1)*3);
   p=(630+first)*512;le32(p,32'h46464952);le32(p+4,12324);le32(p+8,32'h45564157);
   le32(p+12,32'h20746d66);le32(p+16,16);le16(p+20,1);le16(p+22,2);le32(p+24,48000);
   le32(p+28,288000);le16(p+32,6);le16(p+34,24);le32(p+36,32'h61746164);le32(p+40,12288);
   for(n=0;n<12288;n=n+1) begin
    sec=(44+n)/512;cl=first+sec*3;off=(44+n)%512;
    case(n%6) 0:value=left[7:0];1:value=left[15:8];2:value=left[23:16];3:value=right[7:0];4:value=right[15:8];5:value=right[23:16];endcase
    disk[(630+cl)*512+off]=value;
   end
  end
 endtask
 initial begin
  for(i=0;i<512000;i=i+1) disk[i]=0;
  le16(11,512);disk[13]=1;le16(14,32);disk[16]=1;le32(32,70632);le32(36,600);le32(44,2);le16(510,16'haa55);
  le32(32*512+8,32'h0fffffff);
  dirent(0,"2       BMP",100,9270);dirent(1,"1       BMP",10,78);
  dirent(2,"2       WAV",200,12332);dirent(3,"1       WAV",20,12332);
  bmp_file(10,4,2,24'h123456);bmp_file(100,64,48,24'habcd21);
  wav_file(20,24'h010000,24'h020000);wav_file(200,24'hff0000,24'h040000);
 end
 always @(posedge clk) begin
  sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
  if(rst) begin sd_init_done<=0;init_count<=0;busy<=0;end
  else if(!sd_init_done) begin if(init_count==100) sd_init_done<=1;else init_count<=init_count+1;end
  else if(!busy && sd_sec_read) begin busy<=1;waits<=300;bytepos<=0;addr<=sd_sec_read_addr*512;end
  else if(busy) begin
   if(waits!=0) waits<=waits-1;
   else if(bytepos<512) begin sd_sec_read_data<=disk[addr+bytepos];sd_sec_read_data_valid<=1;bytepos<=bytepos+1;end
   else begin sd_sec_read_end<=1;busy<=0;end
  end
 end
endmodule
