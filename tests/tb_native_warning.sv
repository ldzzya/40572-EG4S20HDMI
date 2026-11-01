`timescale 1ns/1ps
// Native 720p media integration: real FAT, decoders, packed write FIFO and
// frame completion; SDRAM application transport is a bounded-latency model.
module tb_native_warning;
 reg clk=0,spi_clk=0;always #6.734 clk=~clk;always #5 spi_clk=~spi_clk;
 reg rst=1,locked=0,key_next=1,key_auto=1,tick=0,finish=0,expect_missing=0,fit=0;
 wire req,we,commit,ack,display,active,swap,warning,restore_cut,autoplay,av;
 wire [31:0] pixel;wire [3:0] status,wstatus;wire [15:0] width,height,sw,sh;
 wire [1:0] wb,db,ab,emergency_bank,held_frame;wire hold_normal;wire [2:0] count;wire [5:0] gain;wire [23:0] al,ar;

 integer cycles=0;
 wire mem_ready,mem_ack,mem_done,are,awe,rv,readack;wire [20:0] ra,wa;wire [31:0] wd,rd;
 reg rr=0;reg [31:0] mrd=0;reg mrv=0;reg memclk=0;always #10.101 memclk=~memclk;
 reg [3:0] drain=0;wire mbusy=drain!=0;reg [2:0] done_sync=0;
 integer physical_words=0;
 assign rv=mrv;assign rd=mrd;
 always @(posedge memclk)begin
  mrv<=are;mrd<=0;
  if(rst)drain<=0;else if(are || awe)drain<=10;else if(drain!=0)drain<=drain-1;
  if(awe)begin
   physical_words=physical_words+1;
   if((^wd)===1'bx)$fatal(1,"unknown packed native data");
  end
 end
 always @(posedge clk)begin
  if(rst)begin done_sync<=0;finish<=0;rr<=0;end
  else begin
   done_sync<={done_sync[1:0],mem_done};if(done_sync[1] && !done_sync[2])finish<=~finish;
   if(cycles==200)rr<=1;else if(readack)rr<=0;
  end
 end
 frame_read_write #(.READ_DATA_BITS(24),.WRITE_DATA_BITS(24),.FRAME_WIDTH(960),.FRAME_HEIGHT(720)) memory_path(
 .rst(rst),.mem_clk(memclk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(mbusy),
 .App_rd_en(are),.App_rd_addr(ra),.Sdr_rd_en(rv),.Sdr_rd_dout(rd),
 .read_clk(clk),.read_req(rr),.read_req_ack(readack),.read_addr_0(21'd0),.read_addr_1(21'd691200),.read_addr_2(21'd1382400),.read_addr_3(21'd0),
 .read_addr_index(2'd0),.read_len(21'd691200),.read_en(1'b0),.read_data(),
 .App_wr_en(awe),.App_wr_addr(wa),.App_wr_din(wd),
 .write_clk(clk),.write_req(req),.write_req_ack(mem_ack),.write_finish(mem_done),
 .write_addr_0(21'd0),.write_addr_1(21'd691200),.write_addr_2(21'd1382400),.write_addr_3(21'd0),
 .write_addr_index(wb),.write_len(21'd691200),.write_en(we),.write_ready(mem_ready),.write_data(pixel[31:8]));
 integer pixels=0,frames=0,swaps=0,ordinary_samples=0,warning_samples=0;
 integer last_words=-1;
 integer old_frames,old_samples,old_swaps,i,mode;reg [31:0] position;
 sd_card_bmp #(.CLK_FREQ_HZ(74250000),.BUTTON_EVENTS(1)) dut(
 .emergency_bank(emergency_bank),.held_frame(held_frame),.hold_normal_frame(hold_normal),.clk(clk),.rst(rst),.spi_clk(spi_clk),.spi_rst(rst),.priority_mode(locked),
 .key_next(key_next),.key_auto(key_auto),.auto_play_en(autoplay),.state_code(status),
 .bmp_width(16'd1280),.bmp_height(16'd720),.display_valid(display),.commit_toggle(commit),.commit_ack(ack),
 .source_width(width),.source_height(height),.write_ready(mem_ready),.write_finish_toggle(finish),
 .write_buf_idx(wb),.disp_buf_idx(db),.write_req(req),.write_req_ack(mem_ack),.write_en(we),.write_data(pixel),
 .SD_MISO(1'b1),.image_count(count),.aspect_fit(fit),.image_swap(swap),.wav_valid(av),
 .wav_left(al),.wav_right(ar),.wav_status(wstatus),.warning_ready(warning),.playback_enable(1'b1),
 .active_frame_buf(ab),.active_frame_valid(active),.active_width(sw),.active_height(sh),.restore_cut(restore_cut));
 defparam dut.bmp_read_m0.OUT_W=1280;
 defparam dut.bmp_read_m0.OUT_H=720;
 frame_presenter #(.FADE_STEP(2)) presenter(.emergency_hold(hold_normal),.clk(clk),.rst(rst),.frame_tick(tick),.request_toggle(commit),
 .requested_buf(db),.source_width(width),.source_height(height),.ack_toggle(ack),.active_buf(ab),
 .display_active(active),.gain(gain),.transition((locked || restore_cut)?2'd2:2'd0),
 .image_swap(swap),.shown_width(sw),.shown_height(sh),.pause_playback(1'b0));
 always @(posedge clk)begin
  cycles<=cycles+1;tick<=cycles%1000==0;
  if(!rst && cycles%500000==499999)begin
   $display("PROGRESS native cycle=%d state=%d bmp=%d pixels=%d writes=%d ready=%b rd_fifo=%d wr_fifo=%d",cycles,dut.state,dut.bmp_read_m0.state,pixels,physical_words,mem_ready,memory_path.wrusedw,memory_path.rdusedw);$fflush();
   if(last_words==physical_words && dut.state==4)$fatal(1,"native media load stopped making progress");
   last_words=physical_words;
  end
  if(rst)pixels<=0;
  else begin
   if(swap)swaps<=swaps+1;
   if(dut.format_reload && !locked && !dut.returning && dut.music.start)
    $fatal(1,"layout-only image swap restarted music");
   if(we)begin
    if(locked && dut.session_active && dut.saved_display && !warning && ab!=dut.saved_buf)
     $fatal(1,"in-flight normal frame exposed during emergency load");
    if(dut.load_index==4)begin
     if(!locked || pixel[31:8]!==24'h426080)
      $fatal(1,"warning image leaked or corrupted pixel=%d value=%h",pixels,pixel);
    end else if(pixel[31:8]!==24'habcd21)$fatal(1,"ordinary picture corrupted");
    if(pixels==921599)begin pixels<=0;frames<=frames+1;end else pixels<=pixels+1;
   end
   if(av && (al!=0 || ar!=0))begin
    if(dut.music.file_cluster==9000)begin
     if(!locked || !warning || al!==24'h010000 || ar!==24'h020000)$fatal(1,"warning audio outside emergency");
     warning_samples<=warning_samples+1;
    end else begin
     if(dut.music.file_cluster!=10000 || al!==24'hff0000 || ar!==24'h040000)$fatal(1,"numeric WAV pairing failed");
     ordinary_samples<=ordinary_samples+1;
    end
   end
   if(!expect_missing && (status==14 || wstatus==4 || wstatus==5))$fatal(1,"unexpected media failure %d/%d",status,wstatus);
   if(warning && !locked)$fatal(1,"overlay outside emergency");
  end
 end

 reg [31:0] saved_position;
 initial begin
  repeat(10)@(negedge clk);rst=0;
  wait(display && dut.state==6);wait(ordinary_samples>50);
  if(count!=2 || frames!=1)$fatal(1,"native boot frame did not commit");
  $display("PASS native boot: 921600 pixels reach frame completion");$fflush();
  @(negedge clk);locked=1;
  wait(warning);wait(warning_samples>50);wait(dut.state==6);
  if(ab!=2 || frames!=2 || !dut.warning_format)$fatal(1,"native warning not committed");
  saved_position=dut.music.saved_position;old_frames=frames;
  $display("PASS native warning: packed 1280x720 RGB/mask decoded, buffer 2 committed, matched 48k WAV playing");$fflush();
  @(negedge clk);locked=0;wait(dut.music.restore_pcm);@(negedge clk);
  if(dut.music.consume_position!=saved_position)$fatal(1,"native warning resume lost audio position");
  wait(!dut.session_active && dut.state==6);
  if(frames!=old_frames || ab==2)$fatal(1,"native restore reloaded image or retained warning");
  $display("PASS native warning integration: numeric slideshow and warning assets isolated; old image/audio restored");$finish;
 end
 initial begin #4000000000.0;$fatal(1,"native warning timeout state=%d pixels=%d",dut.state,pixels);end
endmodule
module sd_card_top #(parameter SPI_LOW_SPEED_DIV=248,SPI_HIGH_SPEED_DIV=0)(
 input clk,rst,output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,output reg sd_init_done,
 input sd_sec_read,input [31:0] sd_sec_read_addr,output reg [7:0] sd_sec_read_data,
 output reg sd_sec_read_data_valid,sd_sec_read_end,input sd_sec_write,input [31:0] sd_sec_write_addr,
 input [7:0] sd_sec_write_data,output sd_sec_write_data_req,sd_sec_write_end
);
 assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=0;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
 reg [7:0] disk[0:5999999];integer i,j,t,a,k,init_count=0,waits=0,bytepos=0,addr=0;reg busy=0;
 string packed_hex;
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
  for(i=0;i<6000000;i=i+1) disk[i]=0;
  le16(11,512);disk[13]=1;le16(14,32);disk[16]=1;le32(32,70632);le32(36,600);le32(44,2);le16(510,16'haa55);
  le32(32*512+8,32'h0fffffff);
  dirent(0,"1       BMP",8000,9270);dirent(1,"2       BMP",8000,9270);dirent(4,"WARNING BMP",10,3686464);
  dirent(2,"1       WAV",10000,12332);dirent(3,"2       WAV",10000,12332);dirent(5,"WARNING WAV",9000,12332);
  bmp_file(8000,64,48,24'habcd21);
  if(!$value$plusargs("PACKED_HEX=%s",packed_hex))packed_hex="build/overlay_720/packed.hex";
  $readmemh(packed_hex,disk,327680,4014143);
  for(i=0;i<7201;i=i+1)le32(32*512+(10+i)*4,i==7200 ? 32'h0fffffff : 11+i);
  wav_file(9000,24'h010000,24'h020000);wav_file(10000,24'hff0000,24'h040000);
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
