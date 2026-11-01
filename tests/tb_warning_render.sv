`timescale 1ns/1ps
module tb_warning_render;
 reg clk=0;always #5 clk=~clk;reg rst=1,frame=0,warning_ready=0;reg [7:0] warning_pixel=8'hc3;
 wire [23:0] rgb;wire de,vs;
 video_effects #(.ENABLE_MENU(1),.BUTTON_EVENTS(1),.WIDTH(1280),.HEIGHT(720),.CLOCK_HZ(74250000),.FRAME_HZ(60)) dut(.clk(clk),.rst(rst),.frame_tick(frame),.warning_pixel(warning_pixel),.warning_ready(warning_ready),.vs(1'b1),.de(1'b1),.rgb(24'h426080),
  .gain(6'd32),.switches(4'd0),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
  .status(4'd1),.image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd2),.autoplay(1'b0),
  .audio_status(4'd3),.audio_valid(1'b0),.audio_left(24'd0),.audio_right(24'd0),.volume_level(5'd20),
  .subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.ui_page(3'd1),.ui_selection(3'd0),
  .ui_field(1'b0),.muted(1'b0),.caption_pause(1'b0),.caption_visible(1'b1),.caption_speed(2'd1),
  .subtitle_updates(4'd0),.english(1'b0),.aspect_fit(1'b0),.transition(2'd0),.out_vs(vs),.out_de(de),.out_rgb(rgb));
 integer xx=500,yy=224,i;reg [23:0] expected;integer weight;
 task settle;begin repeat(12)@(negedge clk);end endtask
 task tick;begin frame=1;@(negedge clk);frame=0;settle();end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  force dut.x=xx;force dut.y=yy;force dut.mode=2;force dut.page_snapshot=1;
  settle();if(rgb!==24'h426080)$fatal(1,"overlay visible in normal mode");
  warning_ready=1;
  for(i=0;i<4;i=i+1)begin
   warning_pixel=8'hc0|i;settle();weight=i==2 ? 3 : i;
   if(i==3)weight=4;
   expected={8'((66*(4-weight)+255*weight)/4),8'(96*(4-weight)/4),8'(128*(4-weight)/4)};
   if(rgb!==expected)$fatal(1,"alpha %d got %h expected %h",i,rgb,expected);
  end
  warning_pixel=0;settle();if(rgb!==24'h426080)$fatal(1,"transparent warning pixels changed BMP");
  warning_pixel=8'hc3;settle();
  for(i=0;i<29;i=i+1)tick();if(rgb!==24'hff0000)$fatal(1,"blink too early");
  tick();if(rgb!==24'h426080)$fatal(1,"off phase missing");
  for(i=0;i<30;i=i+1)tick();if(rgb!==24'hff0000)$fatal(1,"on phase missing");
  warning_ready=0;settle();if(rgb!==24'h426080)$fatal(1,"exit leaves overlay");
  warning_ready=1;settle();if(rgb!==24'hff0000)$fatal(1,"re-entry did not start visible");
  $display("PASS warning pixels: normal mode unchanged, 4 alpha levels, arbitrary banner position, 30-frame on/off, transparent gaps, exit clear, re-entry visible");$finish;
 end
endmodule
