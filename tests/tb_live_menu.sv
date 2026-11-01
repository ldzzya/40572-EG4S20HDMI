`timescale 1ns/1ps
// Real menu -> PCM pause control -> volume -> bars. Compare the PCM stream
// against an always-running reference while physically navigating the menus.
module tb_live_menu;
reg clk=0;always #20 clk=~clk;
reg rst=1,frame=0;reg [2:0] keys=7;
wire playback,down,up,muted;wire [2:0] page,selection;
menu_controller #(.DEBOUNCE_CYCLES(2),.HOLD_CYCLES(30),.REPEAT_CYCLES(12),.SHORT_CYCLES(4)) menu(
 .clk(clk),.rst(rst),.frame_tick(frame),.prev_n(keys[0]),.ok_n(keys[1]),.next_n(keys[2]),.switches(4'd0),
 .ui_page(page),.ui_selection(selection),.volume_down(down),.volume_up(up),.muted(muted),
 .priority_mode(1'b0),.playback_requested(playback));
wire room,pcm_valid,ref_valid;wire [23:0] left,right,ref_left,ref_right;
reg push=0;reg [23:0] sample=0;integer source_index=0;
always @(negedge clk) begin
 push=0;
 if(!rst && room) begin
  sample=$rtoi(1048576.0*$sin(6.283185307179586*100*source_index/48000.0));
  source_index=source_index+1;push=1;
 end
end
wav_pcm_48k stream(.clk(clk),.rst(rst),.flush(1'b0),.enable(1'b1),.rate_44100(1'b0),
 .push(push),.in_left(sample),.in_right(sample),.room(room),.valid(pcm_valid),.left(left),.right(right),
 .pause_playback(!playback),.checkpoint(1'b0),.restore_context(1'b0));
wav_pcm_48k reference(.clk(clk),.rst(rst),.flush(1'b0),.enable(1'b1),.rate_44100(1'b0),
 .push(push),.in_left(sample),.in_right(sample),.valid(ref_valid),.left(ref_left),.right(ref_right),
 .pause_playback(1'b0),.checkpoint(1'b0),.restore_context(1'b0));
wire out_valid;wire [23:0] out_left,out_right;wire [4:0] level;
audio_volume gain(.clk(clk),.rst(rst),.down(down),.up(up),.mute(muted),.in_valid(pcm_valid),
 .in_left(left),.in_right(right),.out_valid(out_valid),.out_left(out_left),.out_right(out_right),.level(level));
wire [6:0] height;
audio_bars bars(.clk(clk),.rst(rst),.frame_tick(frame),.audio_valid(out_valid),
 .audio_left(out_left),.audio_right(out_right),.silent(muted || level==0),.read_index(5'd0),.height(height));
integer samples=0,peak=0,full_peak,half_peak,full_bars,half_bars,i,f;
integer magnitude;
always @(posedge clk) if(!rst) begin
 if(!playback) $fatal(1,"menu paused media page=%d",page);
 if(pcm_valid!==ref_valid || (pcm_valid && {left,right}!=={ref_left,ref_right})) $fatal(1,"menu interrupted PCM progression");
 if(out_valid) begin
  samples=samples+1;magnitude=$signed(out_left);if(magnitude<0)magnitude=-magnitude;
  if(magnitude>peak)peak=magnitude;
 end
end
task latch;begin frame=1;@(negedge clk);frame=0;repeat(240)@(negedge clk);end endtask
task press(input integer k);begin keys[k]=0;repeat(8)@(negedge clk);keys[k]=1;repeat(12)@(negedge clk);latch();end endtask
task home;begin keys[1]=0;repeat(85)@(negedge clk);keys[1]=1;repeat(12)@(negedge clk);latch();if(page!=0)$fatal(1,"home navigation");end endtask
task audio_frame;integer end_sample;begin end_sample=samples+800;wait(samples>=end_sample);@(negedge clk);latch();end endtask
initial begin
 repeat(8)@(negedge clk);rst=0;latch();
 home();press(2);press(1);if(page!=6)$fatal(1,"playback settings navigation");
 repeat(4)press(2);press(1);if(page!=3)$fatal(1,"audio settings navigation");
 for(f=0;f<6;f=f+1)audio_frame();peak=0;audio_frame();full_peak=peak;
 full_bars=0;for(i=0;i<24;i=i+1)full_bars=full_bars+bars.display[i];
 repeat(10)press(0);if(level!=10 || page!=3)$fatal(1,"menu volume must become 50 percent");
 for(f=0;f<10;f=f+1)audio_frame();peak=0;audio_frame();half_peak=peak;
 half_bars=0;for(i=0;i<24;i=i+1)half_bars=half_bars+bars.display[i];
 if(full_peak<1000000 || half_peak<500000 || half_peak>530000) $fatal(1,"audio volume scaling %d/%d",full_peak,half_peak);
 if(half_bars<=0 || half_bars>=full_bars-10)$fatal(1,"menu bars did not fall %d/%d",full_bars,half_bars);
 press(1);audio_frame();if(!muted || peak==0)$fatal(1,"mute command failed");
 for(i=0;i<24;i=i+1)if(bars.display[i]!=0)$fatal(1,"muted bar visible");
 if(out_left!=0 || out_right!=0)$fatal(1,"muted PCM nonzero");
 press(1);audio_frame();if(muted || level!=10)$fatal(1,"unmute must preserve level");
 home();press(2);press(2);press(1);if(page!=2)$fatal(1,"display settings navigation");audio_frame();
 press(2);press(2);press(1);if(page!=4)$fatal(1,"caption settings navigation");audio_frame();
 home();repeat(3)press(2);press(1);if(page!=5)$fatal(1,"diagnostics navigation");audio_frame();
 home();press(1);if(page!=1)$fatal(1,"return gallery navigation");
 $display("PASS live menu: all pages preserve continuous PCM; audio peaks %0d/%0d and bar totals %0d/%0d at 100/50 percent; mute/unmute and gallery return",full_peak,half_peak,full_bars,half_bars);$finish;
end
initial begin #600000000;$fatal(1,"live menu timeout");end
endmodule
