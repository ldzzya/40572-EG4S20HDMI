`timescale 1ns/1ps
// Actual v12 catalogue, FAT cursors, BMP/WAV and presenter. Small output makes
// repeated policy scenarios fast; packed-layer test separately covers 640x480.
module tb_named_warning;
 reg clk=0,spi_clk=0;always #20 clk=~clk;always #5 spi_clk=~spi_clk;
 reg rst=1,locked=0,key_next=1,key_auto=1,tick=0,finish=0,expect_missing=0,fit=0;
 wire req,we,commit,ack,display,active,swap,warning,restore_cut,autoplay,av;
 wire [31:0] pixel;wire [3:0] status,wstatus;wire [15:0] width,height,sw,sh;
 wire [1:0] wb,db,ab,emergency_bank,held_frame;wire hold_normal;wire [2:0] count;wire [5:0] gain;wire [23:0] al,ar;
 integer cycles=0,pixels=0,frames=0,swaps=0,ordinary_samples=0,warning_samples=0;
 integer old_frames,old_samples,old_swaps,i,mode;reg [31:0] position;
 sd_card_bmp #(.CLK_FREQ_HZ(25000000),.BUTTON_EVENTS(1)) dut(
 .emergency_bank(emergency_bank),.held_frame(held_frame),.hold_normal_frame(hold_normal),.clk(clk),.rst(rst),.spi_clk(spi_clk),.spi_rst(rst),.priority_mode(locked),
 .key_next(key_next),.key_auto(key_auto),.auto_play_en(autoplay),.state_code(status),
 .bmp_width(16'd64),.bmp_height(16'd48),.display_valid(display),.commit_toggle(commit),.commit_ack(ack),
 .source_width(width),.source_height(height),.write_ready(cycles%17!=0),.write_finish_toggle(finish),
 .write_buf_idx(wb),.disp_buf_idx(db),.write_req(req),.write_req_ack(req),.write_en(we),.write_data(pixel),
 .SD_MISO(1'b1),.image_count(count),.aspect_fit(fit),.image_swap(swap),.wav_valid(av),
 .wav_left(al),.wav_right(ar),.wav_status(wstatus),.warning_ready(warning),.playback_enable(1'b1),
 .active_frame_buf(ab),.active_frame_valid(active),.active_width(sw),.active_height(sh),.restore_cut(restore_cut));
 defparam dut.bmp_read_m0.OUT_W=64;
 defparam dut.bmp_read_m0.OUT_H=48;
 frame_presenter #(.FADE_STEP(2)) presenter(.emergency_hold(hold_normal),.clk(clk),.rst(rst),.frame_tick(tick),.request_toggle(commit),
 .requested_buf(db),.source_width(width),.source_height(height),.ack_toggle(ack),.active_buf(ab),
 .display_active(active),.gain(gain),.transition((locked || restore_cut)?2'd2:2'd0),
 .image_swap(swap),.shown_width(sw),.shown_height(sh),.pause_playback(1'b0));
 always @(posedge clk)begin
  cycles<=cycles+1;tick<=cycles%1000==0;
  if(rst)pixels<=0;
  else begin
   if(swap)swaps<=swaps+1;
   if(dut.format_reload && !locked && !dut.returning && dut.music.start)
    $fatal(1,"layout-only image swap restarted music");
   if(we)begin
    if(locked && dut.session_active && dut.saved_display && !warning && ab!=dut.saved_buf)
     $fatal(1,"in-flight normal frame exposed during emergency load");
    if(dut.load_index==4)begin
     if(!locked || pixel[31:8]!==((dut.loading_fit && (pixels/64<8 || pixels/64>=40)) ? 24'd0 : 24'h123456))
      $fatal(1,"warning image leaked or corrupted pixel=%d value=%h",pixels,pixel);
    end else if(pixel[31:8]!==24'habcd21)$fatal(1,"ordinary picture corrupted");
    if(pixels==3071)begin pixels<=0;frames<=frames+1;finish<=~finish;end else pixels<=pixels+1;
   end
   if(av && (al!=0 || ar!=0))begin
    if(dut.music.file_cluster==20)begin
     if(!locked || !warning || al!==24'h010000 || ar!==24'h020000)$fatal(1,"warning audio outside emergency");
     warning_samples<=warning_samples+1;
    end else begin
     if(dut.music.file_cluster!=200 || al!==24'hff0000 || ar!==24'h040000)$fatal(1,"numeric WAV pairing failed");
     ordinary_samples<=ordinary_samples+1;
    end
   end
   if(!expect_missing && (status==14 || wstatus==4 || wstatus==5))$fatal(1,"unexpected media failure %d/%d",status,wstatus);
   if(warning && !locked)$fatal(1,"overlay outside emergency");
  end
 end
 task card(input integer kind,input bit boot_locked);begin
  @(negedge clk);rst=1;locked=boot_locked;key_next=1;key_auto=1;fit=0;expect_missing=kind>0;
  repeat(8)@(negedge clk);
  for(i=0;i<512;i=i+1)dut.sd_card_top_m0.disk[632*512+i]=0;
  dut.sd_card_top_m0.le16(11,kind==3 ? 1024:512);
  dut.sd_card_top_m0.dirent(0,"OTHER   BMP",10,78);
  dut.sd_card_top_m0.dirent(1,"WARNING PNG",10,78);
  if(kind!=2)begin
   dut.sd_card_top_m0.dirent(2,"1       BMP",100,9270);
   dut.sd_card_top_m0.dirent(3,"2       BMP",100,9270);
   dut.sd_card_top_m0.dirent(4,"1       WAV",200,12332);
   dut.sd_card_top_m0.dirent(5,"2       WAV",200,12332);
  end else for(i=2;i<6;i=i+1)dut.sd_card_top_m0.disk[632*512+i*32]=8'he5;
  if(kind!=1)begin
   dut.sd_card_top_m0.dirent(6,"WaRnInG bMp",10,78);
   dut.sd_card_top_m0.dirent(7,"WARNING wAv",20,12332);
  end
  rst=0;wait(dut.mounted);repeat(5)@(negedge clk);
 end endtask
 task shown;begin wait(display && dut.state==6);repeat(5)@(negedge clk);end endtask
 task next_image;begin
  old_swaps=swaps;@(negedge clk);key_next=0;repeat(4)@(negedge clk);key_next=1;
  wait(swaps>old_swaps);shown();if(dut.current_index>=2)$fatal(1,"warning entered normal list");
 end endtask
 task alarm_on;begin
  old_samples=warning_samples;@(negedge clk);locked=1;
  wait(warning);wait(warning_samples>old_samples+30);shown();
  if(dut.current_index!=4 || ab!=2)$fatal(1,"warning selection not independent");
 end endtask
 initial begin
  repeat(8)@(negedge clk);card(0,0);shown();old_samples=ordinary_samples;wait(ordinary_samples>old_samples+50);
  if(count!=2 || dut.current_index!=0)$fatal(1,"numeric1 must be ordinary first image");
  old_frames=frames;old_swaps=swaps;old_samples=ordinary_samples;
  @(negedge clk);fit=1;
  wait(swaps>old_swaps);shown();
  if(dut.current_index!=0 || frames!=old_frames+1 || !dut.shown_fit || ordinary_samples<=old_samples)
   $fatal(1,"live fit did not redraw current picture with continuing music");
  repeat(20000)@(negedge clk);
  if(frames!=old_frames+1)$fatal(1,"unchanged layout caused repeated reloads");
  // Coalesce a second edit while a redraw is already underway.
  @(negedge clk);fit=0;wait(dut.state==4);repeat(100)@(negedge clk);fit=1;
  wait(frames==old_frames+3);shown();
  if(!dut.shown_fit || dut.current_index!=0)$fatal(1,"last layout edit lost");
  $display("PASS live fit: same image rebuilt, music continues, edits in flight coalesced");$fflush();
  next_image();next_image();
  @(negedge clk);key_auto=0;repeat(4)@(negedge clk);key_auto=1;repeat(4)@(negedge clk);
  for(mode=0;mode<3;mode=mode+1)begin
   old_swaps=swaps;force dut.auto_count=124999999;wait(dut.state==3);@(negedge clk);release dut.auto_count;
   wait(swaps>old_swaps);shown();if(dut.current_index>=2)$fatal(1,"warning in autoplay");
  end
  $display("PASS named warning: numeric1 audio preserved; manual/autoplay skip all warning and nonnumeric files");$fflush();
  alarm_on();position=dut.music.saved_position;old_frames=frames;
  @(negedge clk);locked=0;wait(dut.music.restore_pcm);@(negedge clk);
  if(dut.music.consume_position!=position || dut.music.file_cluster!=200)$fatal(1,"PCM resume position changed");
  wait(!dut.session_active && dut.state==6);if(frames!=old_frames)$fatal(1,"restore reread BMP");
  old_samples=ordinary_samples;wait(ordinary_samples>old_samples+50);
  $display("PASS named warning: original warning WAV, independent buffer, exact normal music resume without reread");$fflush();
  // Interrupt each stage of a normal next-image transaction. Buffer reuse
  // must still preserve the currently displayed frame and its audio checkpoint.
  for(mode=3;mode<=5;mode=mode+1)begin
   fork
    begin @(negedge clk);key_next=0;repeat(4)@(negedge clk);key_next=1;end
    begin
     if(mode==5)wait(presenter.pending && presenter.state==1);else wait(dut.state==mode);
     alarm_on();
    end
   join
   position=dut.music.saved_position;old_frames=frames;
   @(negedge clk);locked=0;wait(dut.music.restore_pcm);@(negedge clk);
   if(dut.music.consume_position!=position)$fatal(1,"in-flight alarm PCM checkpoint changed");
   wait(!dut.session_active && dut.state==6);
   if(ab!=dut.saved_buf || frames!=old_frames)$fatal(1,"in-flight alarm lost original frame");
  end
  $display("PASS emergency: interrupt LOAD_START, LOAD_WAIT and pending fade; saved frame and PCM survive without reload");$fflush();
  card(0,1);shown();wait(warning);if(dut.current_index!=4)$fatal(1,"emergency boot");
  @(negedge clk);locked=0;wait(!dut.session_active && dut.state==6);old_samples=ordinary_samples;wait(ordinary_samples>old_samples+30);
  card(2,0);wait(dut.state==7);if(count!=0)$fatal(1,"warning consumed normal slot");
  alarm_on();@(negedge clk);locked=0;wait(!dut.session_active);repeat(10000)@(negedge clk);
  if(display || warning || al!=0 || ar!=0)$fatal(1,"warning-only card leaked after unlock");
  $display("PASS named warning: locked startup and warning-only card exit silent/invalid");$fflush();
  card(1,0);shown();old_samples=ordinary_samples;wait(ordinary_samples>old_samples+30);
  @(negedge clk);locked=1;repeat(10000)@(negedge clk);
  if(warning || dut.priority_found || status!=14 || al!=0 || ar!=0)$fatal(1,"missing warning fell back to numeric1");
  card(3,0);wait(dut.state==7);old_frames=frames;repeat(10000)@(negedge clk);
  if(display || frames!=old_frames)$fatal(1,"invalid FAT raw scan bypassed names");
  $display("PASS named warning: missing assets and invalid FAT never fall back to numeric/raw alarm files");$fflush();
  $display("PASS complete named warning media policy");$finish;
 end
 initial begin #2000000000;$fatal(1,"named warning timeout state=%0d index=%0d",dut.state,dut.current_index);end
endmodule
