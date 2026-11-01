module tb_wav_wave;
 reg clk=0;always #5 clk=~clk;reg rst=1,av=0,down=0,muted=0,frame=0;
 reg [23:0] il=0,ir=0;wire ov;wire [23:0] ol,orr;wire [4:0] level;
 audio_volume volume(.clk(clk),.rst(rst),.down(down),.up(1'b0),.mute(muted),.in_valid(av),
  .in_left(il),.in_right(ir),.out_valid(ov),.out_left(ol),.out_right(orr),.level(level));
 video_effects effects(.clk(clk),.rst(rst),.frame_tick(frame),.vs(1'b1),.de(1'b0),.rgb(24'd0),
  .gain(6'd32),.switches(4'd0),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
  .status(4'd1),.image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd1),.autoplay(1'b0),
  .audio_status(4'd3),.audio_valid(ov),.audio_left(ol),.audio_right(orr),.volume_level(level),
  .subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0));
 integer period=48,n=0,i,j,v,lo,hi,lr,hr,crossings,previous,span_full,span_half,cross_low,cross_high;
 task tick_frame;begin frame=1;@(negedge clk);frame=0;end endtask
 task feed(input integer samples);
  integer k,t;begin for(k=0;k<samples;k=k+1) begin
   t=n%period;il=t<period/2 ? -4194304+t*8388608/(period/2) : 4194304-(t-period/2)*8388608/(period/2);
   t=n%32;ir=t<16 ? -2097152+t*4194304/16 : 2097152-(t-16)*4194304/16;
   av=1;@(negedge clk);av=0;repeat(3) @(negedge clk);n=n+1;
  end end
 endtask
 task snapshot;
  begin feed(1400);tick_frame();feed(1400);tick_frame();
   if(!effects.wave_valid) $fatal(1,"no waveform capture");
   lo=127;hi=0;lr=127;hr=0;crossings=0;previous=40;
   for(j=0;j<256;j=j+1) begin
    v=effects.wave_ram[{effects.rd_bank,8'(j)}]&127;
    if(v<lo)lo=v;if(v>hi)hi=v;
    if(previous>40 && v<=40) crossings=crossings+1;previous=v;
    v=effects.wave_ram[{effects.rd_bank,8'(j)}]>>7;
    if(v<lr)lr=v;if(v>hr)hr=v;
   end
  end
 endtask
 initial begin
  repeat(5) @(negedge clk);rst=0;snapshot();span_full=hi-lo;cross_low=crossings;
  if(span_full!=32 || hr-lr!=16 || cross_low<4 || cross_low>6) $fatal(1,"full scale stereo %0d %0d %0d",span_full,hr-lr,cross_low);
  for(i=0;i<10;i=i+1) begin down=1;@(negedge clk);down=0;@(negedge clk);end
  snapshot();span_half=hi-lo;
  if(span_half<15 || span_half>17) $fatal(1,"volume does not control wave amplitude %0d",span_half);
  period=12;snapshot();cross_high=crossings;
  if(cross_high<19 || cross_high>23 || cross_high<cross_low*3) $fatal(1,"pitch period did not shrink %0d %0d",cross_low,cross_high);
  muted=1;snapshot();
  if(lo!=40 || hi!=40 || lr!=40 || hr!=40) $fatal(1,"mute wave not flat");
  $display("PASS real stereo waveform: full/half spans %0d/%0d, pitch crossings %0d/%0d, mute flat",span_full,span_half,cross_low,cross_high);$finish;
 end
endmodule
