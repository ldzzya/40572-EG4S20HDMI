// Synchronous anti-aliased UI; straight borders avoid staircase corners.
module menu_overlay(input clk,input [9:0] x,y,input [2:0] page,selection,input field,
 input [3:0] settings,input [4:0] volume,input muted,paused,visible,
 input [1:0] speed,input [3:0] status,updates,audio_status,input [2:0] images,
 input ready,autoplay,gallery_clean,input [15:0] width_bcd,height_bcd,
 input english,aspect_fit,input [1:0] transition,display_mode,
 input subtitle_active,input [7:0] subtitle_char,input [9:0] scroll,
 input [23:0] uptime,output reg [6:0] subtitle_addr,
 output reg [2:0] style,ink,output [1:0] coverage);
 reg [2:0] paint,fg;reg text_on,big_font,latin,custom_text,dynamic;
 reg [6:0] label;reg [5:0] col;reg [9:0] tx,ty,rt,dx,dy;
 reg [2:0] row;reg [255:0] numbers;reg [8:0] character;
 wire [8:0] stored;wire [1:0] font_coverage;reg text_q;
 wire [6:0] percent=volume*7'd5;
 // Stage A: geometry. Stage B: phrase/dynamic character. Stage C: font.
 reg [6:0] label_a;reg [5:0] col_a;reg english_a;
 reg dynamic_a,custom_a,big_a,text_a,subtitle_a;
 reg [255:0] numbers_a;reg [7:0] subtitle_char_a;
 reg [4:0] dx_a,dy_a,dx_b,dy_b;reg big_b,text_b;
 reg [2:0] paint_a,fg_a,paint_b,fg_b;
 reg [8:0] dynamic_b,custom_b;reg use_dynamic_b,use_custom_b;
 menu_phrase_rom words(clk,english_a,label_a,col_a,stored);
 reg [8:0] character_c;reg big_c,text_c;
 reg [4:0] dx_c,dy_c;reg [2:0] paint_c,fg_c;
 menu_font16 font(clk,character_c,big_c,dx_c,dy_c,font_coverage);
 // Register row/label selection separately from glyph-coordinate math.
 reg [9:0] x_g,y_g,tx_g,ty_g,scroll_g;
 reg [2:0] page_g,paint_g,fg_g;
 reg english_g,latin_g,dynamic_g,custom_g,big_g,text_g,subtitle_g;
 reg [6:0] label_g;reg [255:0] numbers_g;
 always @(posedge clk) begin
  x_g<=x;y_g<=y;tx_g<=tx;ty_g<=ty;scroll_g<=scroll;page_g<=page;
  paint_g<=paint;fg_g<=fg;english_g<=english;latin_g<=latin;dynamic_g<=dynamic;
  custom_g<=custom_text;big_g<=big_font;text_g<=text_on;subtitle_g<=subtitle_active;
  label_g<=label;numbers_g<=numbers;
 end
 reg text_final,latin_final;
 function [7:0] digit;input [3:0] n;begin digit=n<10 ? 48+n : 65+n-10;end endfunction
 always @* begin
  paint=0;fg=4;text_on=0;big_font=0;latin=english;custom_text=0;dynamic=0;
  label=0;tx=80;ty=0;rt=128;row=0;numbers=0;
  if(page!=1) begin
   if(x>=56 && x<600 && y>=40 && y<440) paint=7;
   if(x>=48 && x<592 && y>=32 && y<432) begin
    paint=1;if(x==48 || x==591 || y==32 || y==431) paint=3;if(y==33) paint=6;
   end
   if(y>=52 && y<84) begin text_on=1;big_font=1;ty=52;
    case(page) 0:label=76;2:label=3;3:label=6;4:label=7;5:label=4;6:label=2;default:label=0;endcase
   end
   if(page!=0 && y>=96 && y<112) begin text_on=1;fg=5;ty=96;label=page==0 ? 68 : 9;end
   if(y==120 && x>=80 && x<560) paint=3;
   if(y>=400 && y<416) begin text_on=1;fg=5;ty=400;label=page==0 || page==2 || page==6 ? 63 : 9;end
  end
  if(page==0 || page==2 || page==6) begin
   if(y>=128 && y<368) begin
    if(y>=320) begin row=4;rt=320;end
    else if(y>=272) begin row=3;rt=272;end
    else if(y>=224) begin row=2;rt=224;end
    else if(y>=176) begin row=1;rt=176;end
    if(!(page==2 && row==4)) begin
     if(x>=72 && x<568 && y<rt+40 && row==selection) begin paint=2;if(x<75) paint=6;end
     if(y>=rt+12 && y<rt+28) begin
      text_on=1;tx=96;ty=rt+12;
      if(page==0) label=row+1;else if(page==6) label=row+10;else label=row+15;
      if(x>=360 && page!=0) begin
       tx=360;fg=5;
       if(page==6) case(row)
        0:label=aspect_fit ? 20 : 19;
        1:label=transition==0 ? 21 : transition==1 ? 22 : 23;
        2:label=autoplay ? 24 : 25;3:label=27;4:label=26;
       endcase
       else case(row)
        0:begin dynamic=1;numbers="+00                             ";
         if(settings[1:0]==1) numbers="+32                             ";
         if(settings[1:0]==2) numbers="+64                             ";
         if(settings[1:0]==3) numbers="-32                             ";end
        1:begin dynamic=1;case(settings[3:2])
         0:numbers="1.0                             ";1:numbers="0.5                             ";
         2:numbers="1.5                             ";3:numbers="2.0                             ";endcase end
        2:label=26;3:label=54+display_mode;
       endcase
      end
     end
    end
   end
   if(page==6 && y>=376 && y<392) begin text_on=1;ty=376;fg=5;label=28;end
  end else if(page==3) begin
   if(y>=144 && y<160) begin text_on=1;ty=144;label=29;
    if(x>=360) begin tx=360;dynamic=1;numbers="000%                            ";numbers[255-:8]=percent==100 ? "1" : " ";numbers[247-:8]=48+(percent/10)%10;numbers[239-:8]=48+percent%10;end
   end
   if(y>=180 && y<190 && x>=80 && x<560) begin paint=3;if(!muted && x-80<volume*24) paint=6;end
   if(y>=208 && y<224) begin text_on=1;ty=208;label=30;if(x>=360) begin tx=360;label=muted ? 24 : 25;end end
   if(y>=244 && y<260) begin text_on=1;ty=244;fg=5;label=audio_status==2 ? 72 : audio_status==3 ? 73 : audio_status==4 ? 74 : audio_status==5 ? 75 : 71;
    if(x>=408) begin tx=408;dynamic=1;numbers="48 kHz                          ";end end
   if(y>=284 && y<300) begin text_on=1;ty=284;label=32;end
   if(y>=336) begin paint=0;text_on=0;end
  end else if(page==4) begin
   if(y>=144 && y<160) begin text_on=1;ty=144;label=33;if(x>=360) begin tx=360;label=paused ? 36 : 37;end end
   if(y>=192 && y<208) begin text_on=1;ty=192;label=34;if(x>=360) begin tx=360;label=visible ? 24 : 25;end end
   if(y>=240 && y<256) begin text_on=1;ty=240;label=35;if(x>=360) begin tx=360;label=38+speed;end end
   if(y>=292 && y<308) begin text_on=1;ty=292;label=41;end
   if(y>=340 && y<356) begin text_on=1;ty=340;fg=5;label=59;end
  end else if(page==5) begin
   if(y>=136 && y<388) begin
    if(y>=356) begin row=5;rt=356;end
    else if(y>=312) begin row=4;rt=312;end
    else if(y>=268) begin row=3;rt=268;end
    else if(y>=224) begin row=2;rt=224;end
    else if(y>=180) begin row=1;rt=180;end
    else begin row=0;rt=136;end
    if(y<rt+16) begin text_on=1;ty=rt;label=row==5 ? 69 : 42+row;
     if(x>=328) begin tx=328;fg=5;
      case(row)
       0:label=status<=4 ? 47+status : status==14 ? 52 : 53;
       1:begin dynamic=1;numbers="0                               ";numbers[255-:8]=48+images;end
       2:begin dynamic=1;numbers="0000 x 0000                     ";
        numbers[255-:32]={digit(width_bcd[15:12]),digit(width_bcd[11:8]),digit(width_bcd[7:4]),digit(width_bcd[3:0])};
        numbers[199-:32]={digit(height_bcd[15:12]),digit(height_bcd[11:8]),digit(height_bcd[7:4]),digit(height_bcd[3:0])};end
       3:begin dynamic=1;numbers="0 / 115200                      ";numbers[255-:8]=digit(updates);end
       4:begin dynamic=1;numbers="1280 x 720 / 60                  ";end
       5:label=ready ? 48 : 70;
      endcase
     end
    end
   end
  end
  if(page==1 && display_mode!=3) begin
   if((display_mode==0 || display_mode==1) && x>=24 && x<616 && y>=16 && y<64) paint=1;
   if((display_mode==0 || display_mode==1) && y>=24 && y<40) begin text_on=1;ty=24;tx=40;label=0;
    if(x>=424) begin tx=424;dynamic=1;numbers="00:00:00                        ";
     numbers[255-:16]={digit(uptime[23:20]),digit(uptime[19:16])};numbers[231-:16]={digit(uptime[15:12]),digit(uptime[11:8])};numbers[207-:16]={digit(uptime[7:4]),digit(uptime[3:0])};end
   end
   if((display_mode==0 || display_mode==1) && y>=44 && y<60) begin text_on=1;ty=44;tx=40;fg=5;label=58;end
  end
  if((page==4 || (page==1 && (display_mode==0 || display_mode==1))) && visible && y>=456 && y<472 && x>=24 && x<616) begin
   text_on=1;ty=456;tx=24;label=61;fg=4;paint=1;custom_text=1;big_font=0;
  end
  if(dynamic) latin=1;
 end
 always @* begin
  col=0;subtitle_addr=0;text_final=text_g;latin_final=latin_g;
  dx=x_g-tx_g;dy=y_g-ty_g;
  if(custom_g) begin
   dx=x_g-24+scroll_g;if(dx>=640) dx=dx-640;
   latin_final=subtitle_g ? 1'b1 : english_g;subtitle_addr=dx[9:3];
  end
  col=big_g ? (latin_final ? dx>>4 : dx>>5) : (latin_final ? dx>>3 : dx>>4);
  if(page_g==0 && big_g && !english_g) begin
   if(dx<64) begin col=dx>>4;dx={6'd0,dx[3:0]};end
   else if(dx<288) begin dx=dx-64;col=4+(dx>>5);end
   else if(dx<320) begin dx=dx-288;col=11+(dx>>4);dx={6'd0,dx[3:0]};end
   else begin dx=dx-320;col=13+(dx>>5);end
  end
  if(latin_final) dx=big_g ? {6'd0,dx[3:0]} : {7'd0,dx[2:0]};
  if(x_g<tx_g || (x_g>=576 && page_g!=1 && page_g!=4) || x_g>=616) text_final=0;
 end
 always @* begin
  character=use_custom_b ? custom_b : use_dynamic_b ? dynamic_b : stored;
 end
 always @(posedge clk) begin
  label_a<=label_g;col_a<=col;english_a<=english_g;
  dynamic_a<=dynamic_g;custom_a<=custom_g;big_a<=big_g;text_a<=text_final;
  numbers_a<=numbers_g;subtitle_a<=subtitle_g;subtitle_char_a<=subtitle_char;
  dx_a<=dx[4:0];dy_a<=dy[4:0];paint_a<=paint_g;fg_a<=fg_g;
  dynamic_b<=col_a<32 ? {1'b0,numbers_a[(31-col_a)*8 +:8]} : 9'd32;
  custom_b<={1'b0,subtitle_char_a};use_dynamic_b<=dynamic_a;use_custom_b<=custom_a && subtitle_a;
  dx_b<=dx_a;dy_b<=dy_a;big_b<=big_a;text_b<=text_a;paint_b<=paint_a;fg_b<=fg_a;
  character_c<=character;big_c<=big_b;dx_c<=dx_b;dy_c<=dy_b;
  paint_c<=paint_b;fg_c<=fg_b;text_c<=text_b;
  style<=paint_c;ink<=fg_c;text_q<=text_c;
 end
 assign coverage=text_q ? font_coverage : 2'd0;
endmodule
