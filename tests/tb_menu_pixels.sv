`timescale 1ns/1ps
module tb_menu_pixels;
reg clk=0,rst=1,tick=0;always #20 clk=~clk;
reg[2:0] page=0;reg pause=0,visible=1;reg[1:0] speed=1;
wire ov,od;wire[23:0] rgb;integer i;
video_effects #(.ENABLE_MENU(1)) dut(.clk(clk),.rst(rst),.frame_tick(tick),.vs(1'b1),.de(1'b1),.rgb(24'h4080c0),
 .gain(6'd32),.switches(4'd0),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
 .status(4'd1),.image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd4),.autoplay(1'b0),
 .audio_status(4'd3),.audio_valid(1'b0),.audio_left(24'd0),.audio_right(24'd0),.volume_level(5'd20),.subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),
 .english(1'b0),.aspect_fit(1'b0),.transition(2'd0),.ui_page(page),.ui_selection(3'd0),.ui_field(1'b0),.muted(1'b0),.caption_pause(pause),.caption_visible(visible),.caption_speed(speed),.subtitle_updates(4'd0),
 .out_vs(ov),.out_de(od),.out_rgb(rgb));
task frame;begin tick=1;@(negedge clk);tick=0;@(negedge clk);end endtask
initial begin
 repeat(8) @(negedge clk);rst=0;
 force dut.x=80;force dut.y=200;repeat(7) @(negedge clk);
 if(rgb!==24'h1c3450) $fatal(1,"glass opacity/color mismatch %h",rgb);
 force dut.x=10;repeat(7) @(negedge clk);
 if(rgb!==24'h4080c0) $fatal(1,"menu changed pixels outside its surface");
 force dut.x=80;force dut.y=135;repeat(7) @(negedge clk);
 if(rgb!==24'h1c5871) $fatal(1,"selected surface blend mismatch %h",rgb);
 page=4;repeat(4) @(negedge clk);if(dut.page_snapshot!=0) $fatal(1,"page changed mid-frame");
 frame();if(dut.page_snapshot!=4) $fatal(1,"page not committed");
 pause=1;dut.scroll=100;
 for(i=0;i<10;i=i+1) frame();if(dut.scroll!=100) $fatal(1,"caption pause failed");
 pause=0;speed=2;frame();if(dut.scroll!=102) $fatal(1,"fast caption speed");
 dut.scroll=639;frame();if(dut.scroll!=1) $fatal(1,"fast caption wrap");
 speed=0;i=dut.scroll;frame();frame();if(dut.scroll!=i+1) $fatal(1,"slow caption speed");
 visible=0;frame();force dut.x=32;force dut.y=460;#1;
 if(dut.menu_layer.overlay.text_on) $fatal(1,"hidden caption still draws");
 visible=1;frame();#1;if(!dut.menu_layer.overlay.text_on) $fatal(1,"caption show failed");
 page=3;frame();force dut.mode=3;force dut.x=400;force dut.y=400;#1;
 if(!dut.wave_area) $fatal(1,"audio submenu hid bars due to gallery mode");
 $display("PASS menu pixels: alpha blend, unaffected background, frame-latched pages, pause/speed/wrap/hide captions, audio-page bars");$finish;
end
endmodule

