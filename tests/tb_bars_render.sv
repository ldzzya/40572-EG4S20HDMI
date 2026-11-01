`timescale 1ns/1ps
module tb_bars_render;
 reg clk=0;always #5 clk=~clk;reg rst=1;
 wire [23:0] rgb;wire de,vs;
 video_effects #(.ENABLE_MENU(1)) dut(.clk(clk),.rst(rst),.frame_tick(1'b0),.vs(1'b1),.de(1'b1),.rgb(24'h426080),
  .gain(6'd32),.switches(4'd0),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
  .status(4'd1),.image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd2),.autoplay(1'b0),
  .audio_status(4'd3),.audio_valid(1'b0),.audio_left(24'd0),.audio_right(24'd0),.volume_level(5'd20),
  .subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.ui_page(3'd1),.ui_selection(3'd0),
  .ui_field(1'b0),.muted(1'b0),.caption_pause(1'b0),.caption_visible(1'b1),.caption_speed(2'd1),
  .subtitle_updates(4'd0),.english(1'b0),.aspect_fit(1'b0),.transition(2'd0),.out_vs(vs),.out_de(de),.out_rgb(rgb));
 integer xx=0,yy=0,i,pass,changed=0,fd,index,h;reg expected;
 initial begin
  repeat(4) @(negedge clk);rst=0;
  force dut.x=xx;force dut.y=yy;force dut.mode=2;force dut.page_snapshot=1;
  if(240*104>640*480/6) $fatal(1,"visualization exceeds one sixth");
  for(pass=0;pass<2;pass=pass+1)begin
   for(i=0;i<24;i=i+1) dut.bars.display[i]=pass==0 ? 12+(i*37)%93 : 0;
   fd=$fopen(pass==0 ? "build/bars_sim/bars.ppm" : "build/bars_sim/silence.ppm","w");
   $fwrite(fd,"P3\n640 480\n255\n");
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<640;xx=xx+1)begin
    @(negedge clk);repeat(3)begin @(posedge clk);#1;end
    expected=0;
    if(xx>=376 && xx<616 && yy>=336 && yy<440)begin
     index=(xx-376)/10;h=pass==0 ? 12+(index*37)%93 : 0;
     expected=(xx-376)%10<8 && 439-yy<h;
    end
    if(expected && rgb==24'h426080)$fatal(1,"missing solid bar at %d %d",xx,yy);
    if(!expected && rgb!==24'h426080)$fatal(1,"unexpected panel/border/title/grid at %d %d: %h",xx,yy,rgb);
    if(expected)changed=changed+1;
    $fwrite(fd,"%0d %0d %0d\n",rgb[23:16],rgb[15:8],rgb[7:0]);
   end
   $fclose(fd);
  end
  if(changed<4000)$fatal(1,"bars not visually substantial");
  $display("PASS bar pixels: 24 columns only, transparent gaps, no border/panel/title/grid, right-bottom 8.125%% box, silent frame unchanged");$finish;
 end
endmodule
