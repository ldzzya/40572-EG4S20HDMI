`timescale 1ns/1ps
// Real timing -> pixel delay -> OSD -> AXIS; real PCM + ACR.
// No SD image and no SDRAM acknowledgement: startup must still emit video/audio.
module tb_menu_chain;
reg [2:0] keys=7;
wire [2:0] page,selection;wire field,mute,pause,shown;wire [1:0] speed;
wire [3:0] settings;wire next_n,auto_n,mode_n,vdown,vup;

reg clk=0,rst=1;always #20 clk=~clk;
wire hs,vs,de,hd,vd,dd,re,req,fv,fd,sof,valid,last,av,acr;
wire [23:0] raw,rgb,pixel,pcm_l,pcm_r;wire [19:0] cts,n;
video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(req),.read_req_ack(1'b0),.hs(hs),.vs(vs),.de(de));
video_delay delay(.video_clk(clk),.rst(rst),.read_en(re),.read_data(24'd0),.hs(hs),.vs(vs),.de(de),.hs_r(hd),.vs_r(vd),.de_r(dd),.vout_data(raw));
reg req_d=0;wire tick=req && !req_d;always @(posedge clk) req_d<=req;
reg ui_vs_d=0;
wire ui_tick=vd && !ui_vs_d;
always @(posedge clk) if(rst) ui_vs_d<=0;else ui_vs_d<=vd;
wire tone_valid;wire[23:0] tone_l,tone_r;wire[4:0] volume_level;
tone_pcm_48k audio_source(clk,rst,tone_valid,tone_l,tone_r);
audio_volume audio_gain(clk,rst,1'b0,1'b0,tone_valid,tone_l,tone_r,av,pcm_l,pcm_r,volume_level,1'b0);
audio_arc_calculate #(.ACR_N(6144)) arc(clk,rst,av,acr,cts,n);
video_effects #(.ENABLE_MENU(1)) effects(.clk(clk),.rst(rst),.frame_tick(ui_tick),.vs(vd),.de(dd),.rgb(raw),
 .english(1'b0),.aspect_fit(1'b0),.transition(2'd0),.ui_page(page),.ui_selection(selection),.ui_field(field),.muted(mute),
 .caption_pause(pause),.caption_visible(shown),.caption_speed(speed),.subtitle_updates(4'd0),.gain(6'd0),.switches(4'd0),.volume_level(5'd20),.subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.subtitle_addr(),.mode_key(1'b1),.source_width(16'd0),.source_height(16'd0),
 .status(4'd0),.image_ready(1'b0),.scan_sector(32'd0),.image_count(3'd0),.autoplay(1'b0),
 .audio_status(4'd3),.audio_valid(av),.audio_left(pcm_l),.audio_right(pcm_l),.out_vs(fv),.out_de(fd),.out_rgb(rgb));
video_rgb_to_axis_640x480 adapter(clk,rst,fv,fd,rgb,sof,valid,last,pixel);
integer pixels=0,lines=0,frames=0,samples=0,nonzero=0,col=0,lit=0,cycles=0,previous_sof=0,acrs=0;
integer boot_file,audio_file;
initial begin boot_file=$fopen("boot_menu.hex","w");audio_file=$fopen("audio_menu.hex","w");end
menu_controller #(.DEBOUNCE_CYCLES(2),.HOLD_CYCLES(30),.REPEAT_CYCLES(12),.SHORT_CYCLES(4))
 controls(clk,rst,ui_tick,keys[0],keys[1],keys[2],4'd0,page,selection,field,settings,next_n,auto_n,mode_n,vdown,vup,mute,pause,shown,speed,,,,1'b0,);
task press(input integer k);begin keys[k]=0;repeat(8) @(negedge clk);keys[k]=1;repeat(10) @(negedge clk);end endtask
initial begin wait(!rst);wait(frames==1);repeat(400) @(negedge clk);press(2);press(1);repeat(4) press(2);press(1);end

always @(posedge clk) begin
 #1;
 if(!rst) begin
  cycles=cycles+1;
  if(av) begin samples=samples+1;if(pcm_l!=0 && pcm_r!=0) nonzero=nonzero+1;end
  // ACR payload is specified only while acr is high; it is zero otherwise.
  if(acr) begin
   acrs=acrs+1;
   if(acrs>1 && (cts!=25000 || n!=6144)) $fatal(1,"bad valid ACR packet: CTS=%0d N=%0d",cts,n);
  end
  if(valid) begin
   if(sof) begin
    if(frames!=0 && (pixels!=307200 || lines!=480 || cycles-previous_sof!=420000))
     $fatal(1,"bad frame geometry pixels=%0d lines=%0d clocks=%0d",pixels,lines,cycles-previous_sof);
    frames=frames+1;pixels=0;lines=0;col=0;previous_sof=cycles;
   end
   if(frames==1) $fwrite(boot_file,"%06x\n",pixel);
   if(frames==3) $fwrite(audio_file,"%06x\n",pixel);
   if(last!==(col==639)) $fatal(1,"HDMI line marker missing at x=%0d",col);
   if($isunknown(pixel)) $fatal(1,"undefined startup pixel");
   if(pixel!=0) lit=lit+1;
   pixels=pixels+1;
   if(last) begin lines=lines+1;col=0;end else col=col+1;
  end
  if(frames==4) begin
   if(effects.page_snapshot!=3) $fatal(1,"menu did not enter audio on frame boundary");
   $fclose(boot_file);$fclose(audio_file);
   if(samples<1600 || nonzero<1500 || lit<500000 || acrs<30)
    $fatal(1,"startup AV absent: samples=%0d nonzero=%0d lit=%0d ACRs=%0d",samples,nonzero,lit,acrs);
   $display("PASS menu chain: boot without SD, navigation during active video, 3 complete 640x480 frames, 800x525 timing, exact AXIS markers, visible startup with no SD/SDRAM ACK, continuous PCM and correct ACR");$finish;
  end
 end
end
initial begin repeat(8) @(negedge clk);rst=0;end
initial begin #90000000;$fatal(1,"display timeout");end
endmodule
