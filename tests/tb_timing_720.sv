`timescale 1ns/1ps
module tb_timing_720;
 reg clk=0;always #5 clk=~clk;reg rst=1;wire hs,vs,de;wire req;
 reg vprev=0;wire frame=vs && !vprev;always @(posedge clk)vprev<=vs;
 video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(req),.read_req_ack(req),.hs(hs),.vs(vs),.de(de));
 wire fvs,fde;wire [23:0] rgb;wire [6:0] unused;
 wire hit=fx.x>=500 && fx.x<780 && fx.y>=224 && fx.y<280;
 video_effects #(.ENABLE_MENU(1),.BUTTON_EVENTS(1),.WIDTH(1280),.HEIGHT(720),.CLOCK_HZ(74250000),.FRAME_HZ(60)) fx(
 .clk(clk),.rst(rst),.frame_tick(frame),.vs(vs),.de(de),.rgb(24'h426080),.gain(6'd32),.switches(4'd0),.mode_key(1'b1),
 .source_width(16'd1280),.source_height(16'd720),.status(4'd1),.image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd2),.autoplay(1'b0),
 .audio_status(4'd2),.audio_valid(1'b0),.audio_left(24'd0),.audio_right(24'd0),.volume_level(5'd20),.subtitle_active(1'b0),
 .subtitle_char(8'd32),.subtitle_changed(1'b0),.subtitle_addr(unused),.ui_page(3'd1),.ui_selection(3'd0),.ui_field(1'b0),
 .muted(1'b0),.caption_pause(1'b0),.caption_visible(1'b0),.caption_speed(2'd1),.subtitle_updates(4'd0),.english(1'b0),
 .aspect_fit(1'b1),.transition(2'd2),.out_vs(fvs),.out_de(fde),.out_rgb(rgb),.priority_mode(1'b1),
 .warning_pixel(hit ? 8'hc3:8'd0),.warning_ready(1'b1));
 wire valid,user,last;wire [23:0] data;
 video_rgb_to_axis_640x480 #(.WIDTH(1280)) axis(.I_clk(clk),.I_rst(rst),.I_vs(fvs),.I_de(fde),.I_rgb(rgb),
 .O_video_user(user),.O_video_valid(valid),.O_video_last(last),.O_video_data(data));
 integer x=0,y=0,pixels=0,lines=0,sofs=0,frame_cycles=0,period=0,prev_frame=0;reg collecting=0;
 always @(negedge clk) if(!rst)begin
  frame_cycles=frame_cycles+1;
  if(frame)begin
   if(prev_frame!=0 && frame_cycles-prev_frame!=1237500)$fatal(1,"not 1650x750 timing");
   prev_frame=frame_cycles;
  end
  if(valid)begin
   if(user)begin
    if(collecting)begin
     if(pixels!=921600 || lines!=720)$fatal(1,"frame dimensions %d/%d",pixels,lines);
     $display("PASS native 720p output: 1650x750 timing, 1280x720 unique active positions, TLAST every 1280 pixels, one SOF; warning covers BMP pixels at y=224");$finish;
    end
    collecting=1;x=0;y=0;pixels=0;lines=0;sofs=sofs+1;
   end
   if(collecting)begin
    if(last!==(x==1279))$fatal(1,"TLAST x=%d y=%d",x,y);
    if(y>=200 && y<400)begin
     if(x>=500 && x<780 && y>=224 && y<280)begin
      if(data!==24'hff0000)$fatal(1,"overlay misplaced %d/%d %h",x,y,data);
     end else if(data!==24'h426080)$fatal(1,"base image moved or changed %d/%d %h",x,y,data);
    end
    pixels=pixels+1;
    if(last)begin lines=lines+1;x=0;y=y+1;end else x=x+1;
   end
  end
 end
 initial begin repeat(10)@(negedge clk);rst=0;end
 initial begin #40000000;$fatal(1,"720p timing timeout");end
endmodule
