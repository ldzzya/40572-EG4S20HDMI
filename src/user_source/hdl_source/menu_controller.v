// Page 0 home, 1 gallery, 2 display, 3 audio, 4 captions, 5 diagnostics.
// All buttons are physical active-low KEY2/KEY3/KEY4 in the video clock domain.
module menu_controller #(
 parameter CLK_HZ=25000000,parameter DEBOUNCE_CYCLES=CLK_HZ/50,
 parameter HOLD_CYCLES=CLK_HZ*3/5,parameter REPEAT_CYCLES=CLK_HZ/6,
 parameter SHORT_CYCLES=CLK_HZ*3/100
)(input clk,rst,frame_tick,input prev_n,ok_n,next_n,input [3:0] switches,
 output reg [2:0] ui_page,ui_selection,output reg ui_field,
 output [3:0] display_settings,output next_image_n,auto_play_n,mode_n,
 output reg volume_down,volume_up,output reg muted,
 output reg caption_pause,caption_visible,output reg [1:0] caption_speed,
 output reg english,aspect_fit,output reg [1:0] transition,input priority_mode,output reg playback_requested);
 wire locked=priority_mode===1'b1;
 wire gesture_reset=rst || locked;
 wire p_short_n,o_short_n,n_short_n,p_long,o_long,n_long;
 key_gesture #(.CLK_HZ(CLK_HZ),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.HOLD_CYCLES(HOLD_CYCLES),.REPEAT_CYCLES(REPEAT_CYCLES),.SHORT_CYCLES(SHORT_CYCLES))
  kp(clk,gesture_reset,prev_n,p_short_n,p_long);
 key_gesture #(.CLK_HZ(CLK_HZ),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.HOLD_CYCLES(HOLD_CYCLES),.REPEAT_CYCLES(REPEAT_CYCLES),.SHORT_CYCLES(SHORT_CYCLES))
  ko(clk,gesture_reset,ok_n,o_short_n,o_long);
 key_gesture #(.CLK_HZ(CLK_HZ),.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),.HOLD_CYCLES(HOLD_CYCLES),.REPEAT_CYCLES(REPEAT_CYCLES),.SHORT_CYCLES(SHORT_CYCLES))
  kn(clk,gesture_reset,next_n,n_short_n,n_long);
 reg ps,os,ns;
 wire p_press=ps && !p_short_n,o_press=os && !o_short_n,n_press=ns && !n_short_n;
 wire decrease=p_press || p_long,increase=n_press || n_long;
 reg [2:0] page,selection;
 reg field;
 reg [1:0] brightness,contrast;
 // Physical switch brightness/contrast controls removed; menus own settings.
 reg [$clog2(SHORT_CYCLES+1)-1:0] image_count,auto_count,mode_count;
 wire [1:0] bcode=brightness==0 ? 2'd3 : brightness-1'b1;
 wire [1:0] ccode=contrast==0 ? 2'd1 : contrast==1 ? 2'd0 : contrast;
 assign display_settings={ccode,bcode};
 assign next_image_n=locked || image_count==0;
 assign auto_play_n=locked || auto_count==0;
 assign mode_n=locked || mode_count==0;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   playback_requested<=1;ps<=1;os<=1;ns<=1;page<=1;selection<=0;field<=0;
   ui_page<=1;ui_selection<=0;ui_field<=0;
   brightness<=1;contrast<=1;
   image_count<=0;auto_count<=0;mode_count<=0;volume_down<=0;volume_up<=0;
   muted<=0;caption_pause<=0;caption_visible<=1;caption_speed<=1;english<=0;aspect_fit<=0;transition<=0;
  end else begin
   ps<=p_short_n;os<=o_short_n;ns<=n_short_n;
   volume_down<=0;volume_up<=0;
   if(image_count!=0) image_count<=image_count-1'b1;
   if(auto_count!=0) auto_count<=auto_count-1'b1;
   if(mode_count!=0) mode_count<=mode_count-1'b1;
   // Frame-latched page/selection prevent half-frame menu tearing.
   if(frame_tick) begin ui_page<=page;ui_selection<=selection;ui_field<=field;end
   // Menu navigation overlays live media; it never pauses playback.
   // A held OK returns home, never also confirms on release.
   if(locked) begin image_count<=0;auto_count<=0;mode_count<=0;end
   else if(o_long) begin page<=0;selection<=0;end
   else case(page)
    0:begin
     if(decrease && !increase) selection<=selection==0 ? 4 : selection-1'b1;
     else if(increase && !decrease) selection<=selection==4 ? 0 : selection+1'b1;
     if(o_press) begin
      case(selection)
       0:begin page<=1;playback_requested<=1;end 1:page<=6;2:page<=2;3:page<=5;4:english<=~english;
      endcase
      if(selection!=4) selection<=0;
     end
    end
    1:begin
     if(p_press) image_count<=SHORT_CYCLES;
     if(n_press) auto_count<=SHORT_CYCLES;
     if(o_press) mode_count<=SHORT_CYCLES;
     volume_down<=p_long && !n_long;volume_up<=n_long && !p_long;
    end
    2,6:begin
     if(decrease && !increase) selection<=selection==0 ? (page==6 ? 4 : 3) : selection-1'b1;
     else if(increase && !decrease) selection<=selection==(page==6 ? 4 : 3) ? 0 : selection+1'b1;
     if(o_press) begin
      if(page==6) case(selection)
       0:aspect_fit<=~aspect_fit;
       1:transition<=transition==2 ? 0 : transition+1'b1;
       2:auto_count<=SHORT_CYCLES;
       3:image_count<=SHORT_CYCLES;
       4:begin page<=3;selection<=0;end
      endcase
      else case(selection)
       0:brightness<=brightness==3 ? 0 : brightness+1'b1;
       1:contrast<=contrast==3 ? 0 : contrast+1'b1;
       2:begin page<=4;selection<=0;end
       3:mode_count<=SHORT_CYCLES;
      endcase
     end
    end
    3:begin
     volume_down<=decrease && !increase;volume_up<=increase && !decrease;
     if(o_press) muted<=~muted;
    end
    4:begin
     if(p_press) caption_pause<=~caption_pause;
     if(n_press) caption_speed<=caption_speed==2 ? 0 : caption_speed+1'b1;
     if(o_press) caption_visible<=~caption_visible;
    end
    default:begin end
   endcase

  end
 end
endmodule
