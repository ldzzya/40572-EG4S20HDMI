// Debounced active-low button: short action on release; long action repeats.
// Short output lasts 30 ms so the existing SD key debouncer is preserved.
module key_gesture #(
 parameter CLK_HZ=25000000, parameter DEBOUNCE_CYCLES=CLK_HZ/50,
 parameter HOLD_CYCLES=CLK_HZ*3/5, parameter REPEAT_CYCLES=CLK_HZ/6,
 parameter SHORT_CYCLES=CLK_HZ*3/100
)(input clk,rst,button_n,output short_n,output reg long_pulse);
 reg [1:0] sync;
 reg stable,held;
 reg [$clog2(DEBOUNCE_CYCLES+1)-1:0] debounce_count;
 // Hold and repeat are mutually exclusive phases; share their elapsed timer.
 localparam TIMER_CYCLES=HOLD_CYCLES>REPEAT_CYCLES ? HOLD_CYCLES : REPEAT_CYCLES;
 reg [$clog2(TIMER_CYCLES+1)-1:0] gesture_count;
 reg [$clog2(SHORT_CYCLES+1)-1:0] short_count;
 wire released_now=sync[1] && !stable && debounce_count==DEBOUNCE_CYCLES-1;
 assign short_n=(short_count==0);
 always @(posedge clk or posedge rst) begin
  if(rst) begin sync<=3;stable<=1;held<=0;debounce_count<=0;
   gesture_count<=0;short_count<=0;long_pulse<=0;end
  else begin
   sync<={sync[0],button_n};long_pulse<=0;
   if(short_count!=0) short_count<=short_count-1'b1;
   if(sync[1]==stable) debounce_count<=0;
   else if(debounce_count==DEBOUNCE_CYCLES-1) begin
    debounce_count<=0;stable<=sync[1];
    if(sync[1] && !held) short_count<=SHORT_CYCLES;
   end else debounce_count<=debounce_count+1'b1;
   // Release wins on the exact hold boundary: never emit both gestures.
   if(stable || released_now) begin gesture_count<=0;held<=0;end
   else if(!held) begin
    if(gesture_count==HOLD_CYCLES-1) begin held<=1;long_pulse<=1;gesture_count<=0;end
    else gesture_count<=gesture_count+1'b1;
   end else if(gesture_count==REPEAT_CYCLES-1) begin gesture_count<=0;long_pulse<=1;end
   else gesture_count<=gesture_count+1'b1;
  end
 end
endmodule
