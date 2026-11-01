`timescale 1ns/1ps
module tb_home_media;
 reg clk=0,spi_clk=0;always #20 clk=~clk;always #5 spi_clk=~spi_clk;
 reg playback=0;wire bg_ready;reg rst=1,key_next=1,key_auto=1,locked=0,tick=0,finish=0;
 wire req,we,commit,ack,display,active,swap;wire [31:0] pixel;wire [3:0] status,wav_status;
 wire [15:0] width,height;wire [1:0] wb,db,ab;wire [2:0] count;wire [5:0] gain;
 wire av,autoplay,warning_ready;wire [23:0] al,ar;
 integer cycles=0,pixels=0,frames=0,swaps=0,audio1=0,audio2=0,lastswap=0,i,heldframes;reg [1:0] audible_index=0;
 sd_card_bmp #(.CLK_FREQ_HZ(25000000),.BUTTON_EVENTS(1)) dut(.clk(clk),.rst(rst),.spi_clk(spi_clk),.spi_rst(rst),
  .playback_enable(playback),.background_ready(bg_ready),.warning_ready(warning_ready),.priority_mode(locked),.key_next(key_next),.key_auto(key_auto),.auto_play_en(autoplay),.state_code(status),.bmp_width(16'd640),.bmp_height(16'd480),
  .display_valid(display),.commit_toggle(commit),.commit_ack(ack),.source_width(width),.source_height(height),
  .write_ready(cycles%17!=0),.write_finish_toggle(finish),.write_buf_idx(wb),.disp_buf_idx(db),
  .write_req(req),.write_req_ack(req),.write_en(we),.write_data(pixel),.SD_MISO(1'b1),
  .image_count(count),.aspect_fit(1'b0),.image_swap(swap),.wav_valid(av),.wav_left(al),.wav_right(ar),.wav_status(wav_status));
 frame_presenter #(.FADE_STEP(2)) presenter(.pause_playback(!playback && !locked),.clk(clk),.rst(rst),.frame_tick(tick),.request_toggle(commit),
  .requested_buf(db),.source_width(width),.source_height(height),.ack_toggle(ack),.active_buf(ab),
  .display_active(active),.gain(gain),.transition(locked ? 2'd2 : 2'd0),.image_swap(swap));
 always @(posedge clk) begin
  cycles<=cycles+1;tick<=cycles%1000==0;
  if(warning_ready && !locked)$fatal(1,"warning gate leaked outside emergency mode");
  if(swap) begin lastswap<=cycles;audible_index<=dut.load_index;swaps<=swaps+1;end
  if(!rst && we) begin
   if(wb!=2 && dut.load_index==1)begin
    if(pixel[7:0]!==((pixels>=256000 && ((pixels%640)/16)%4!=0) ? (8'hc0|(((pixels%640)/16)%4)) : 8'd0))$fatal(1,"SDRAM warning byte mismatch pixel=%d %h",pixels,pixel);
   end else if(pixel[7:0]!==0)$fatal(1,"ordinary picture contains a warning");
   if(pixel[31:8] !== (wb==2 ? 24'h123456 : dut.load_index==1 ? 24'h426080 : 24'habcd21))$fatal(1,"priority BMP corrupted");
   if(pixels==307199)begin pixels<=0;frames<=frames+1;finish<=~finish;end else pixels<=pixels+1;
  end
  if(!rst && av && cycles-lastswap>4 && (al!=0 || ar!=0)) begin
   if(!playback && !locked)$fatal(1,"home audio not silent");
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
 integer saved_frames,saved_swaps,saved_auto,saved_rp,saved_phase;
 initial begin
  repeat(8)@(negedge clk);rst=0;wait(bg_ready);repeat(5000)@(negedge clk);
  if(count!=2 || frames!=1 || swaps!=0 || display || wav_status!=0)$fatal(1,"home loaded media or counted background");
  @(negedge clk);playback=1;wait(display);wait(audio2>=100);wait(dut.state==6);
  if(frames!=2)$fatal(1,"initial play failed");
  key_auto=0;repeat(4)@(negedge clk);key_auto=1;repeat(100)@(negedge clk);
  playback=0;repeat(600)@(negedge clk);
  saved_auto=dut.auto_count;saved_rp=dut.music.output_pcm.rp;saved_phase=dut.music.output_pcm.phase;
  saved_frames=frames;saved_swaps=swaps;
  repeat(60000)@(negedge clk);
  if(frames!=saved_frames || swaps!=saved_swaps || dut.auto_count!=saved_auto || dut.music.output_pcm.rp!=saved_rp || dut.music.output_pcm.phase!=saved_phase)$fatal(1,"home failed to pause");
  playback=1;wait(audio2>=180);repeat(200)@(negedge clk);
  if(frames!=saved_frames || swaps!=saved_swaps || !bg_ready)$fatal(1,"resume reloaded frame");
  playback=0;repeat(600)@(negedge clk);locked=1;
  wait(warning_ready);wait(audio1>=100);wait(dut.state==6);
  if(dut.current_index!=1 || frames!=3 || !bg_ready)$fatal(1,"priority override from home");
  locked=0;repeat(600)@(negedge clk);saved_frames=frames;
  repeat(5000)@(negedge clk);if(frames!=saved_frames || warning_ready || al!=0 || ar!=0)$fatal(1,"priority exit failed to restore paused home");
  $display("PASS home media: FAT long-name background in buffer 2 excluded from playlist, no boot WAV/media, start required, pause preserves PCM position and auto timer, resume without reload, SW1 override and home restoration");$finish;
 end
 initial begin #2000000000;$fatal(1,"warning media timeout frames=%d state=%d",frames,dut.state);end
endmodule
module sd_card_top #(parameter SPI_LOW_SPEED_DIV=248,SPI_HIGH_SPEED_DIV=0)(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output reg sd_init_done,
 input sd_sec_read,input [31:0] sd_sec_read_addr,output reg [7:0] sd_sec_read_data,
 output reg sd_sec_read_data_valid,sd_sec_read_end,input sd_sec_write,input [31:0] sd_sec_write_addr,
 input [7:0] sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end
);
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 reg [7:0] disk[0:2999999];integer i,j,t,a,k,init_count=0,waits=0,bytepos=0,addr=0;reg busy=0;
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
 task background_name;
  integer p,q,n;reg [7:0] sum;reg [87:0] alias_name;reg [111:0] long_name;
  begin
   alias_name="BACKGR~1BMP";long_name="background.bmp";sum=0;
   for(q=0;q<11;q=q+1)sum={sum[0],sum[7:1]}+alias_name[(10-q)*8+:8];
   for(n=0;n<2;n=n+1)begin
    p=632*512+(4+n)*32;for(q=0;q<32;q=q+1)disk[p+q]=8'hff;
    disk[p]=n==0 ? 8'h42 : 8'h01;disk[p+11]=15;disk[p+12]=0;disk[p+13]=sum;le16(p+26,0);
    for(q=0;q<13;q=q+1)begin
     k=q<5 ? 1+q*2 : q<11 ? 14+(q-5)*2 : 28+(q-11)*2;
     if(n==1)le16(p+k,{8'd0,long_name[(13-q)*8+:8]});
     else if(q==0)le16(p+k,16'h0070);else if(q==1)le16(p+k,0);
    end
   end
   dirent(6,alias_name,10,78);
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
  for(i=0;i<3000000;i=i+1) disk[i]=0;
  le16(11,512);disk[13]=1;le16(14,32);disk[16]=1;le32(32,70632);le32(36,600);le32(44,2);le16(510,16'haa55);
  le32(32*512+8,32'h0fffffff);
  dirent(0,"2       BMP",100,9270);dirent(1,"1       BMP",1000,1228854);
  dirent(2,"2       WAV",200,12332);dirent(3,"1       WAV",20,12332);
  background_name();bmp_file(10,4,2,24'h123456);bmp_file(100,64,48,24'habcd21);
  $readmemh("build/warning_sim/packed.hex",disk,834560,2063413);
  for(i=0;i<2401;i=i+1)le32(32*512+(1000+i)*4,i==2400 ? 32'h0fffffff : 1001+i);
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
