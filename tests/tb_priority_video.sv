`timescale 1ns/1ps
module tb_priority_video;
 reg clk=0;always #20 clk=~clk;reg rst=1,tick=0,key_n=1,locked=0;
 wire ov,od;wire [23:0] rgb;
 video_effects #(.ENABLE_MENU(1),.BUTTON_EVENTS(1)) dut(
  .clk(clk),.rst(rst),.frame_tick(tick),.vs(1'b1),.de(1'b1),.rgb(24'h426080),.gain(6'd32),
  .switches(4'd0),.mode_key(key_n),.priority_mode(locked),.source_width(16'd640),.source_height(16'd480),
  .status(4'd1),.image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd2),.autoplay(1'b0),
  .audio_status(4'd3),.audio_valid(1'b0),.audio_left(24'd0),.audio_right(24'd0),.volume_level(5'd20),
  .subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.subtitle_updates(4'd0),
  .ui_page(locked ? 3'd1 : 3'd5),.ui_selection(3'd0),.ui_field(1'b0),.muted(1'b0),
  .caption_pause(1'b0),.caption_visible(1'b1),.caption_speed(2'd1),.english(1'b0),.aspect_fit(1'b0),
  .transition(2'd2),.out_vs(ov),.out_de(od),.out_rgb(rgb));
 task frame;begin tick=1;@(negedge clk);tick=0;repeat(3)@(negedge clk);end endtask
 task press;begin key_n=0;repeat(4)@(negedge clk);key_n=1;repeat(4)@(negedge clk);end endtask
 integer i;
 initial begin
  repeat(5)@(negedge clk);rst=0;press();frame();
  if(dut.mode!=1 || dut.page_snapshot!=5)$fatal(1,"normal mode event");
  locked=1;frame();
  for(i=0;i<8;i=i+1)begin press();frame();end
  if(dut.mode!=1 || dut.next_mode!=1 || dut.page_snapshot!=1)$fatal(1,"locked video mode/page changed");
  locked=0;frame();press();frame();
  if(dut.mode!=2 || dut.page_snapshot!=5)$fatal(1,"video restore");
  $display("PASS priority video: menu-to-gallery override, blocked mode pulses, retained mode and restored page, normal mode resumes");$finish;
 end
endmodule
