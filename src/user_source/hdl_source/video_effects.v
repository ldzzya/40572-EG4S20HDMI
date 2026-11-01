// Pipelined contrast, brightness, fade, OSD and actual PCM waveform.
module video_effects #(parameter ENABLE_MENU=0,parameter BUTTON_EVENTS=0,parameter WIDTH=640,HEIGHT=480,CLOCK_HZ=25000000,FRAME_HZ=60)(
 input clk,rst,frame_tick,vs,de, input [23:0] rgb,
 input [5:0] gain, input [3:0] switches, input mode_key,
 input [15:0] source_width,source_height, input [3:0] status,
 input image_ready,input [31:0] scan_sector,input [2:0] image_count,input autoplay,
 input [3:0] audio_status,input audio_valid, input [23:0] audio_left,audio_right,
 input [4:0] volume_level, input subtitle_active,input [7:0] subtitle_char,
 input subtitle_changed,output [6:0] subtitle_addr,
 input [2:0] ui_page,ui_selection,input ui_field,muted,caption_pause,caption_visible,
 input [1:0] caption_speed,input [3:0] subtitle_updates,
 input english,aspect_fit,input [1:0] transition,
 output reg out_vs,out_de, output reg [23:0] out_rgb,input priority_mode,input [7:0] warning_pixel,input warning_ready
);
 // Emergency pixels are composited at their packed image coordinates. RGBA2222 is stored
 // in the previously unused framebuffer byte. Reuse the existing alpha mixer.
 reg [5:0] warning_frames;reg warning_visible;
 wire warning_active=warning_ready===1'b1;
 reg [7:0] warning1,warning2;
 always @(posedge clk or posedge rst) begin
  if(rst) begin warning_frames<=0;warning_visible<=1;end
  else if(!warning_active) begin warning_frames<=0;warning_visible<=1;end
  else if(frame_tick) begin
   if(warning_frames==FRAME_HZ/2-1) begin warning_frames<=0;warning_visible<=~warning_visible;end
   else warning_frames<=warning_frames+1'b1;
  end
 end
 reg [3:0] sw_meta,sw_sync,sw_active;
 wire mode_press;
 reg [1:0] mode;
 wire locked=priority_mode===1'b1;
 generate if(BUTTON_EVENTS) begin:mode_event
  reg last_n;
  always @(posedge clk or posedge rst) if(rst) last_n<=1;else last_n<=mode_key;
  assign mode_press=last_n && !mode_key && !locked;
 end else begin:mode_button
  key_press_debounce #(.CLK_FREQ_HZ(25000000),.DEBOUNCE_MS(20)) key_filter
   (.clk(clk),.rst(rst || locked),.button_in(mode_key),.press_pulse(mode_press));
 end endgenerate
 reg [1:0] next_mode;
 reg [10:0] x,y;
 reg de_d;
 reg [9:0] scroll;
 reg scroll_half;
 reg [2:0] page_snapshot,selection_snapshot;
 reg field_snapshot,mute_snapshot,pause_snapshot,visible_snapshot;
 reg [1:0] speed_snapshot;
 reg [3:0] updates_snapshot;
 reg english_snapshot,fit_snapshot;reg [1:0] transition_snapshot;
 reg [6:0] legacy_subtitle_addr;wire [6:0] menu_subtitle_addr;
 assign subtitle_addr=ENABLE_MENU ? menu_subtitle_addr : legacy_subtitle_addr;
 wire [1:0] render_mode=!ENABLE_MENU || page_snapshot==1 ? mode : page_snapshot==3 ? 2 : (page_snapshot==2 || page_snapshot==4) ? 1 : 3;
 always @(posedge clk or posedge rst) begin
  if(rst) begin page_snapshot<=0;selection_snapshot<=0;field_snapshot<=0;mute_snapshot<=0;
   pause_snapshot<=0;visible_snapshot<=1;speed_snapshot<=1;updates_snapshot<=0;english_snapshot<=0;fit_snapshot<=0;transition_snapshot<=0;end
  else if(frame_tick) begin page_snapshot<=ui_page;selection_snapshot<=ui_selection;
   field_snapshot<=ui_field;mute_snapshot<=muted;pause_snapshot<=caption_pause;
   visible_snapshot<=caption_visible;speed_snapshot<=caption_speed;updates_snapshot<=subtitle_updates;english_snapshot<=english;fit_snapshot<=aspect_fit;
   if(gain==32 || !image_ready) transition_snapshot<=transition;end
 end
 reg [$clog2(CLOCK_HZ)-1:0] seconds_div;
 reg [3:0] s0,s1,m0,m1,h0,h1;
 reg [23:0] time_snapshot;
 reg [3:0] status_snapshot;
 reg [31:0] sector_snapshot;
 reg [2:0] count_snapshot;
 reg autoplay_snapshot;reg [3:0] audio_snapshot;
 always @(posedge clk or posedge rst) begin
  if(rst) begin audio_snapshot<=0;time_snapshot<=0;status_snapshot<=0;sector_snapshot<=0;count_snapshot<=0;autoplay_snapshot<=0;end
  else if(frame_tick) begin
   audio_snapshot<=audio_status;time_snapshot<={h1,h0,m1,m0,s1,s0};status_snapshot<=status;
   sector_snapshot<=scan_sector;count_snapshot<=image_count;autoplay_snapshot<=autoplay;
  end
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   sw_meta<=0;sw_sync<=0;sw_active<=0;mode<=0;next_mode<=0;
   x<=0;y<=0;de_d<=0;scroll<=0;scroll_half<=0;seconds_div<=0;
   s0<=0;s1<=0;m0<=0;m1<=0;h0<=0;h1<=0;
  end else begin
   sw_meta<=switches;sw_sync<=sw_meta;de_d<=de;
   if(mode_press && !locked) next_mode<=next_mode+1'b1;
   if(frame_tick) begin
    sw_active<=sw_sync;mode<=next_mode;scroll_half<=~scroll_half;
    if(subtitle_changed) scroll<=0;
    else if(!ENABLE_MENU) scroll<=scroll==639 ? 0 : scroll+1'b1;
    else if(!caption_pause && (caption_speed!=0 || scroll_half)) begin
     if(caption_speed==2) scroll<=scroll>=638 ? scroll-638 : scroll+2;
     else scroll<=scroll==639 ? 0 : scroll+1'b1;
    end
   end
   if(!vs) begin x<=0;y<=0;end
   else if(de) x<=x==WIDTH-1 ? 0 : x+1'b1;
   if(de_d && !de) y<=y==HEIGHT-1 ? 0 : y+1'b1;
   if(seconds_div==CLOCK_HZ-1) begin
    seconds_div<=0;
    if(s0==9) begin s0<=0;
     if(s1==5) begin s1<=0;
      if(m0==9) begin m0<=0;
       if(m1==5) begin m1<=0;
        if(h1==2 && h0==3) begin h1<=0;h0<=0;end
        else if(h0==9) begin h0<=0;h1<=h1+1'b1;end
        else h0<=h0+1'b1;
       end else m1<=m1+1'b1;
      end else m0<=m0+1'b1;
     end else s1<=s1+1'b1;
    end else s0<=s0+1'b1;
   end else seconds_div<=seconds_div+1'b1;
  end
 end
 // Borderless 24-bar visualization. Its bounding box is 240 x 104 pixels
 // (8.125% of 640 x 480), right-aligned above the unchanged caption strip.
 reg [4:0] volume_snapshot;
 always @(posedge clk or posedge rst)
  if(rst) volume_snapshot<=20;else if(frame_tick) volume_snapshot<=volume_level;
 wire [6:0] volume_percent=volume_snapshot*7'd5;
 // The region is only 240 pixels wide; mask wraps outside it with bar_region.
 wire [9:0] bar_rx=WIDTH==1280 ? x>>1 : x;
 wire [9:0] bar_ry=HEIGHT==720 ? (y+240)>>1 : y;
 wire [7:0] bar_x=bar_rx[7:0]-8'd120;
 wire [4:0] bar_index=bar_x/8'd10;
 wire [7:0] column_x=bar_x-bar_index*8'd10;
 wire [6:0] bar_height;
 wire bars_enabled=render_mode==0 || render_mode==2;
 wire bar_region=bar_rx>=376 && bar_rx<616 && bar_ry>=336 && bar_ry<440;
 wire [9:0] from_bottom=439-bar_ry;
 wire bar_hit=bars_enabled && bar_region && column_x<8 && from_bottom<bar_height;
 wire [23:0] bar_color=from_bottom>=72 ? 24'hff4d89 : from_bottom>=36 ? 24'hb35bff : 24'h00dfff;
 audio_bars bars(.clk(clk),.rst(rst),.frame_tick(frame_tick),.audio_valid(audio_valid),
  .audio_left(audio_left),.audio_right(audio_right),
  .silent(volume_level==0 || (ENABLE_MENU && muted)),.read_index(bar_index),.height(bar_height));
 function [7:0] adjust;
  input [7:0] c; input [1:0] b,k;
  reg signed [11:0] t;
  begin
   t=$signed({1'b0,c})-12'sd128;
   case(k)
    1:t=t>>>1;
    2:t=t+(t>>>1);
    3:t=t<<<1;
   endcase
   t=t+12'sd128;
   case(b) 1:t=t+32;2:t=t+64;3:t=t-32;endcase
   adjust=t<0 ? 0 : t>255 ? 255 : t[7:0];
  end
 endfunction
 function [7:0] hexchar;
  input [3:0] n;begin hexchar=n<10 ? 8'd48+n : 8'd65+n-10;end
 endfunction
 // Status uses fixed-width decimal dimensions, evaluated outside the pixel path.
 reg [15:0] width_bcd,height_bcd;
 function [15:0] bcd4;
  input [15:0] value;
  integer i,j; reg [31:0] shift;
  begin
   shift={16'b0,value};
   for(i=0;i<16;i=i+1) begin
    for(j=0;j<4;j=j+1) if(shift[16+j*4 +:4]>=5) shift[16+j*4 +:4]=shift[16+j*4 +:4]+3;
    shift=shift<<1;
   end
   bcd4=shift[31:16];
  end
 endfunction
 reg [31:0] width_shift,height_shift;reg [4:0] bcd_step;
 reg [31:0] width_adjust,height_adjust;integer bcd_digit;
 always @* begin
  width_adjust=width_shift;height_adjust=height_shift;
  for(bcd_digit=0;bcd_digit<4;bcd_digit=bcd_digit+1) begin
   if(width_shift[16+bcd_digit*4 +:4]>=5) width_adjust[16+bcd_digit*4 +:4]=width_shift[16+bcd_digit*4 +:4]+3;
   if(height_shift[16+bcd_digit*4 +:4]>=5) height_adjust[16+bcd_digit*4 +:4]=height_shift[16+bcd_digit*4 +:4]+3;
  end
 end
 always @(posedge clk or posedge rst) begin
  if(rst)begin width_shift<=0;height_shift<=0;bcd_step<=17;width_bcd<=0;height_bcd<=0;end
  else if(frame_tick)begin width_shift<={16'd0,source_width};height_shift<={16'd0,source_height};bcd_step<=0;end
  else if(bcd_step<16)begin width_shift<=width_adjust<<1;height_shift<=height_adjust<<1;bcd_step<=bcd_step+1'b1;end
  else if(bcd_step==16)begin width_bcd<=width_shift[31:16];height_bcd<=height_shift[31:16];bcd_step<=17;end
 end
 reg [7:0] character;
 reg [8*24-1:0] state_label;
 localparam [8*80-1:0] DIAG="STATE:                          FOUND:0   AUTO:OFF    LBA:00000000              ";
 always @* begin
  case(status_snapshot)
   0:state_label="SD INITIALIZING         ";
   1:state_label="READY                   ";
   2:state_label="SEARCHING BMP           ";
   3:state_label="LOADING FRAME           ";
   4:state_label="SMOOTH TRANSITION       ";
   14:state_label="READ ERROR - KEY2 RETRY ";
   15:state_label="NO BMP IN FIRST 64MIB   ";
   default:state_label="WAIT                    ";
  endcase
 end
 reg text_area,panel,wave_area,grid,accent,meter;
 reg [10:0] tx;
 reg [2:0] font_x;
 reg [3:0] font_y;
 reg [6:0] col;
 wire [7:0] glyph_row;
 font8x16 font(.character(character),.row(font_y),.bits(glyph_row));
 localparam [8*74-1:0] TITLE="HX4S20  /  PHOTO GALLERY                                00:00:00          ";
 localparam [8*74-1:0] INFO="SRC 0000x0000  EQ   AUTO OFF     VOL 100%       IMG 0   B+00 C1.0         ";
 localparam [8*80-1:0] TICKER="  HOLD KEY2: VOL-   HOLD KEY4: VOL+   |   USB: TEXT your message                ";
 always @* begin
  character=32;text_area=0;panel=0;accent=0;meter=0;
  tx=x;font_x=x[2:0];font_y=y[3:0];col=0;legacy_subtitle_addr=0;
  wave_area=bars_enabled && bar_region;grid=0;
  if(render_mode==0 || render_mode==1 || !image_ready || status_snapshot==14 || status_snapshot==15) begin
   if(x>=16 && x<624 && y>=12 && y<52) begin
    panel=(x>=20 && x<620) || (y>=16 && y<48);
    accent=panel && y==12;
    if(x>=24 && x<616 && y>=16 && y<48) begin
     text_area=1;col=(x-24)>>3;
     if(y<32) begin
      character=TITLE[(73-col)*8 +:8];
      case(col)
       56:character=48+time_snapshot[23:20];57:character=48+time_snapshot[19:16];
       59:character=48+time_snapshot[15:12];60:character=48+time_snapshot[11:8];
       62:character=48+time_snapshot[7:4];63:character=48+time_snapshot[3:0];
      endcase
     end else begin
      character=INFO[(73-col)*8 +:8];
      case(col)
       4:character=hexchar(width_bcd[15:12]);5:character=hexchar(width_bcd[11:8]);
       6:character=hexchar(width_bcd[7:4]);7:character=hexchar(width_bcd[3:0]);
       9:character=hexchar(height_bcd[15:12]);10:character=hexchar(height_bcd[11:8]);
       11:character=hexchar(height_bcd[7:4]);12:character=hexchar(height_bcd[3:0]);
       15:character=(source_width<=640 && source_height<=480 && (source_width<640 || source_height<480)) ? "B" : source_width==640 && source_height==480 ? "E" : "N";
       16:character=(source_width<=640 && source_height<=480 && (source_width<640 || source_height<480)) ? "L" : source_width==640 && source_height==480 ? "Q" : "N";
       25:character="O";
       26:character=autoplay_snapshot ? "N" : "F";
       27:character=autoplay_snapshot ? " " : "F";
       37:character=volume_percent==100 ? "1" : " ";
       38:character=48+(volume_percent/10)%10;
       39:character=48+volume_percent%10;
       52:character=48+count_snapshot;
       57:character=sw_active[1:0]==3 ? "-" : "+";
       58:character=sw_active[1:0]==2 ? "6" : sw_active[1:0]==0 ? "0" : "3";
       59:character=sw_active[1:0]==2 ? "4" : sw_active[1:0]==0 ? "0" : "2";
       62:character=sw_active[3:2]==1 ? "0" : sw_active[3:2]==3 ? "2" : "1";
       64:character=(sw_active[3:2]==1 || sw_active[3:2]==2) ? "5" : "0";
      endcase
     end
    end
   end
   if(x>=16 && x<624 && y>=56 && y<72 && (!image_ready || status_snapshot==14 || status_snapshot==15)) begin
    panel=1;text_area=1;font_y=y-56;col=x[9:3];character=DIAG[(79-col)*8 +:8];
    if(col>=7 && col<31) character=state_label[(30-col)*8 +:8];
    if(col==38) character=48+count_snapshot;
    if(col==47) character="O";
    if(col==48) character=autoplay_snapshot ? "N" : "F";
    if(col==49) character=autoplay_snapshot ? " " : "F";
    if(col>=58 && col<66) character=hexchar(sector_snapshot[(65-col)*4 +:4]);
   end
   if((!ENABLE_MENU || visible_snapshot) && x>=16 && x<624 && y>=452 && y<476) begin
    panel=(x>=20 && x<620) || (y>=456 && y<472);
    accent=panel && y==475;
    if(x>=24 && x<616 && y>=456 && y<472) begin
     text_area=1;tx={1'b0,x}-11'd24+{1'b0,scroll};
     if(tx>=640) tx=tx-640;
     col=tx[9:3];legacy_subtitle_addr=col;
     character=subtitle_active ? subtitle_char : TICKER[(79-col)*8 +:8];
     font_x=tx[2:0];font_y=y-456;
    end
   end
  end
  if(ENABLE_MENU) begin
   text_area=0;panel=0;accent=0;

  end
 end
 wire [2:0] menu_style,menu_ink;wire [1:0] menu_coverage;
 reg [9:0] menu_x,menu_y;
 always @(posedge clk) begin
  menu_x<=x-(WIDTH-640)/2;
  menu_y<=page_snapshot==1 ? (y<80 ? y : y>=HEIGHT-60 ? y-(HEIGHT-480) : 10'd800) : y-(HEIGHT-480)/2;
 end
 generate if(ENABLE_MENU) begin:menu_layer
  menu_overlay overlay(.clk(clk),.x(menu_x),.y(menu_y),.page(page_snapshot),.selection(selection_snapshot),
   .field(field_snapshot),.settings(sw_active),.volume(volume_snapshot),.muted(mute_snapshot),
   .paused(pause_snapshot),.visible(visible_snapshot),.speed(speed_snapshot),.status(status_snapshot),
   .audio_status(audio_snapshot),.updates(updates_snapshot),.images(count_snapshot),.ready(image_ready),.autoplay(autoplay_snapshot),
   .gallery_clean(mode==3),.width_bcd(width_bcd),.height_bcd(height_bcd),.style(menu_style),.ink(menu_ink),.coverage(menu_coverage),
   .english(english_snapshot),.aspect_fit(fit_snapshot),.transition(transition_snapshot),.display_mode(mode),
   .subtitle_active(subtitle_active),.subtitle_char(subtitle_char),.scroll(scroll),.uptime(time_snapshot),.subtitle_addr(menu_subtitle_addr));
 end else begin:no_menu_layer
  assign menu_style=0;assign menu_ink=0;assign menu_coverage=0;assign menu_subtitle_addr=0;
 end endgenerate
 reg [2:0] menu2,ink2;reg [1:0] coverage2;
 function [23:0] menu_blend;
  input [2:0] kind;input [23:0] color;
  begin
   case(kind)
    1:menu_blend={({2'b0,color[23:18]}+8'd12),({2'b0,color[15:10]}+8'd20),({2'b0,color[7:2]}+8'd32)};
    2:menu_blend={({2'b0,color[23:18]}+8'd12),({2'b0,color[15:10]}+8'd56),({2'b0,color[7:2]}+8'd65)};
    3:menu_blend=24'h365568;
    4:menu_blend=24'heef6fa;
    5:menu_blend=24'hafc5d3;
    6:menu_blend=24'h54dec5;
    7:menu_blend={1'b0,color[23:17],1'b0,color[15:9],1'b0,color[7:1]};
    default:menu_blend=color;
   endcase
  end
 endfunction
 // Pipeline 1: enhancement and pixel classification. Pipeline 2: fade.
 // Pipeline 3: alpha panel and glyph/wave composition. DE/VS follow all stages.
 reg [23:0] enhanced,enhanced_d1,enhanced_d2,enhanced_d3,enhanced_d4,enhanced_d5;
 reg [5:0] gain_d1,gain_d2,gain_d3,gain_d4,gain_d5;
 reg [7:0] warning3,warning4,warning5,warning6;
 reg vs5,vs6,de5,de6;
 reg [7:0] warning7;reg vs7,de7;
 reg text7,panel7,accent7,meter7,bar_hit7;reg [23:0] bar_color7;
 reg text5,text6,panel5,panel6,accent5,accent6,meter5,meter6,bar_hit5,bar_hit6;
 reg [23:0] bar_color5,bar_color6;
 reg vs3,vs4,de3,de4;
 reg text3,text4,panel3,panel4,accent3,accent4,meter3,meter4,bar_hit3,bar_hit4;
 reg [23:0] bar_color3,bar_color4;
 reg [13:0] fade_r,fade_g,fade_b;
 wire [23:0] boot_rgb={8'h18+{3'b0,x[9:5]},8'h20+{4'b0,y[8:5]},8'h38};
 wire [23:0] base_rgb=image_ready ? rgb : boot_rgb;
 wire curtain_hidden=transition_snapshot==1 && (x<WIDTH/2-gain*(WIDTH/64) || x>=WIDTH/2+gain*(WIDTH/64));
 wire [5:0] applied_gain=image_ready ? (ENABLE_MENU && transition_snapshot==1 ? (curtain_hidden ? 0 : 32) : gain) : 6'd32;
 reg [5:0] gain1;
 reg vs1,de1,vs2,de2;
 reg text1,text2,panel1,panel2,wave1,wave2,grid1,grid2,accent1,accent2,meter1,meter2;
 reg bar_hit1,bar_hit2;
 reg [23:0] bar_color1,bar_color2;
 // Compose panels first, then blend the four-level font against the actual panel/background.
 reg [23:0] composed;
 always @* begin
  composed={fade_r[12:5],fade_g[12:5],fade_b[12:5]};
  if(menu2!=0) composed=menu_blend(menu2,composed);
  else if(text7) composed=24'hf0f4ff;
  else if(accent7 || meter7) composed=24'h4cdbc3;
  else if(bar_hit7) composed=bar_color7;
  else if(panel7) composed=menu_blend(1,composed);
 end
 function [23:0] alpha_ink;
  input [23:0] bg,fg;input [1:0] a;
  integer k;reg [9:0] mix;
  begin
   alpha_ink=bg;
   for(k=0;k<3;k=k+1) begin
    case(a)
     0:mix={2'b0,bg[k*8 +:8]}<<2;
     1:mix=({2'b0,bg[k*8 +:8]}<<1)+bg[k*8 +:8]+fg[k*8 +:8];
     2:mix=bg[k*8 +:8]+({2'b0,fg[k*8 +:8]}<<1)+fg[k*8 +:8];
     3:mix={2'b0,fg[k*8 +:8]}<<2;
    endcase
    alpha_ink[k*8 +:8]=mix[9:2];
   end
  end
 endfunction
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   enhanced_d5<=0;gain_d5<=32;warning7<=0;vs7<=0;de7<=0;
   text7<=0;panel7<=0;accent7<=0;meter7<=0;bar_hit7<=0;bar_color7<=0;
   enhanced_d3<=0;enhanced_d4<=0;gain_d3<=32;gain_d4<=32;
   warning5<=0;warning6<=0;vs5<=0;vs6<=0;de5<=0;de6<=0;
   text5<=0;text6<=0;panel5<=0;panel6<=0;accent5<=0;accent6<=0;meter5<=0;meter6<=0;
   bar_hit5<=0;bar_hit6<=0;bar_color5<=0;bar_color6<=0;
   enhanced_d1<=0;enhanced_d2<=0;gain_d1<=32;gain_d2<=32;
   warning3<=0;warning4<=0;vs3<=0;vs4<=0;de3<=0;de4<=0;
   text3<=0;text4<=0;panel3<=0;panel4<=0;accent3<=0;accent4<=0;meter3<=0;meter4<=0;
   bar_hit3<=0;bar_hit4<=0;bar_color3<=0;bar_color4<=0;
   warning1<=0;warning2<=0;menu2<=0;ink2<=0;coverage2<=0;gain1<=32;enhanced<=0;fade_r<=0;fade_g<=0;fade_b<=0;vs1<=0;de1<=0;vs2<=0;de2<=0;
   accent1<=0;accent2<=0;meter1<=0;meter2<=0;text1<=0;text2<=0;panel1<=0;panel2<=0;wave1<=0;wave2<=0;grid1<=0;grid2<=0;
   bar_hit1<=0;bar_hit2<=0;bar_color1<=0;bar_color2<=0;out_vs<=0;out_de<=0;out_rgb<=0;
  end else begin
   warning1<=warning_active && warning_visible && image_ready ? warning_pixel : 8'd0;warning2<=warning1;
   menu2<=menu_style;ink2<=menu_ink;coverage2<=menu_coverage;gain1<=applied_gain;
   enhanced<={adjust(base_rgb[23:16],sw_active[1:0],sw_active[3:2]),
              adjust(base_rgb[15:8],sw_active[1:0],sw_active[3:2]),
              adjust(base_rgb[7:0],sw_active[1:0],sw_active[3:2])};
   accent1<=accent;meter1<=meter;vs1<=vs;de1<=de;text1<=text_area && glyph_row[7-font_x];panel1<=panel;
   bar_hit1<=bar_hit;bar_color1<=bar_color;bar_hit2<=bar_hit1;bar_color2<=bar_color1;
   enhanced_d1<=enhanced;enhanced_d2<=enhanced_d1;gain_d1<=gain1;gain_d2<=gain_d1;
   warning3<=warning2;warning4<=warning3;vs3<=vs2;vs4<=vs3;de3<=de2;de4<=de3;
   text3<=text2;text4<=text3;panel3<=panel2;panel4<=panel3;accent3<=accent2;accent4<=accent3;meter3<=meter2;meter4<=meter3;
   bar_hit3<=bar_hit2;bar_hit4<=bar_hit3;bar_color3<=bar_color2;bar_color4<=bar_color3;
   enhanced_d3<=enhanced_d2;enhanced_d4<=enhanced_d3;gain_d3<=gain_d2;gain_d4<=gain_d3;
   warning5<=warning4;warning6<=warning5;vs5<=vs4;vs6<=vs5;de5<=de4;de6<=de5;
   text5<=text4;text6<=text5;panel5<=panel4;panel6<=panel5;accent5<=accent4;accent6<=accent5;meter5<=meter4;meter6<=meter5;
   bar_hit5<=bar_hit4;bar_hit6<=bar_hit5;bar_color5<=bar_color4;bar_color6<=bar_color5;
   enhanced_d5<=enhanced_d4;gain_d5<=gain_d4;warning7<=warning6;vs7<=vs6;de7<=de6;
   text7<=text6;panel7<=panel6;accent7<=accent6;meter7<=meter6;bar_hit7<=bar_hit6;bar_color7<=bar_color6;
   fade_r<=enhanced_d5[23:16]*gain_d5;fade_g<=enhanced_d5[15:8]*gain_d5;fade_b<=enhanced_d5[7:0]*gain_d5;
   accent2<=accent1;meter2<=meter1;vs2<=vs1;de2<=de1;text2<=text1;panel2<=panel1;wave2<=wave1;grid2<=grid1;

   out_vs<=vs7;out_de<=de7;
   if(!de7) out_rgb<=0;
   else out_rgb<=ENABLE_MENU ? alpha_ink(composed,
    warning7[1:0]!=0 ? {{4{warning7[7:6]}},{4{warning7[5:4]}},{4{warning7[3:2]}}} : (ink2==5 ? 24'hafc5d3 : 24'heef6fa),
    warning7[1:0]!=0 ? warning7[1:0] : coverage2) : composed;
  end
 end
endmodule


