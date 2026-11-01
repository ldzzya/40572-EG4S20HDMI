// Post-volume stereo filter bank: 12 bands, adjacent L/R bars.
// Shared filter/peak RAM and multiplier fit the small FPGA. A sample costs
// 145 clocks and a display refresh 72 clocks, below one 48 kHz period (520).
module audio_bars(
 input clk,rst,frame_tick,audio_valid,input [23:0] audio_left,audio_right,
 input silent,input [4:0] read_index,output [6:0] height
);
 // Each word stores {7-bit accumulated visual peak, 25-bit signed filter}.
 (* ram_style="block" *) reg [31:0] memory[0:255];
 reg [31:0] memory_q;
 reg initializing;reg [7:0] init_index;
 reg [6:0] display[0:23];
 reg signed [24:0] dc_l,dc_r,clean_l,clean_r,previous_l,previous_r;
 reg signed [24:0] next_filter;
 reg signed [25:0] delta,band;
 reg signed [35:0] product;
 reg [8:0] coefficient;
 reg [4:0] index,frame_index;reg [3:0] state;
 reg frame_pending,audio_pending;
 reg [6:0] frame_old;
 // The RAM read address stays fixed throughout states 7--9.
 wire [6:0] frame_peak=memory_q[31:25];
 wire [24:0] frame_filter=memory_q[24:0];
 wire [7:0] read_addr=state>=7 ? {3'b0,frame_index} : {3'b0,index};
 wire signed [24:0] old_filter=$signed(memory_q[24:0]);
 wire signed [24:0] pcm_l=$signed({audio_left[23],audio_left});
 wire signed [24:0] pcm_r=$signed({audio_right[23],audio_right});
 wire [25:0] magnitude=band[25] ? -band : band;
 wire [17:0] level=magnitude[25:8];
 reg [6:0] mapped;
 wire [6:0] next_peak=mapped>memory_q[31:25] ? mapped : memory_q[31:25];
 integer i;
 assign height=read_index<24 ? display[read_index] : 0;
 // Static graphics compression, not audio gain or automatic normalization.
 always @* begin
  if(level<64) mapped=level>>3;
  else if(level<256) mapped=8+((level-64)>>4);
  else if(level<1024) mapped=20+((level-256)>>5);
  else if(level<4096) mapped=44+((level-1024)>>6);
  else if(level<16384) mapped=92+((level-4096)>>10);
  else mapped=104;
 end
 function [8:0] coeff;
  input [3:0] n;
  begin case(n)
   0:coeff=1;1:coeff=2;2:coeff=3;3:coeff=5;4:coeff=8;5:coeff=13;
   6:coeff=21;7:coeff=34;8:coeff=55;9:coeff=89;10:coeff=144;default:coeff=255;
  endcase end
 endfunction
 always @(posedge clk) begin
  if(initializing) memory[init_index]<=0;
  else if(state==6) memory[{3'b0,index}]<={next_peak,next_filter};
  else if(state==9) memory[{3'b0,frame_index}]<={7'd0,frame_filter};
  memory_q<=memory[read_addr];
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   dc_l<=0;dc_r<=0;clean_l<=0;clean_r<=0;previous_l<=0;previous_r<=0;
   initializing<=1;init_index<=0;frame_pending<=0;audio_pending<=0;
   frame_index<=0;frame_old<=0;
   next_filter<=0;delta<=0;band<=0;product<=0;coefficient<=0;index<=0;state<=0;
   for(i=0;i<24;i=i+1) display[i]<=0;
  end else begin
   if(initializing) begin init_index<=init_index+1'b1;if(init_index==255) initializing<=0;end
   if(frame_tick) frame_pending<=1;
   if(audio_valid && !initializing) begin
    dc_l<=dc_l+((pcm_l-dc_l)>>>10);dc_r<=dc_r+((pcm_r-dc_r)>>>10);
    clean_l<=pcm_l-dc_l;clean_r<=pcm_r-dc_r;audio_pending<=1;
   end
   case(state)
    0:if(!initializing) begin
     if(audio_pending) begin
      previous_l<=0;previous_r<=0;index<=0;state<=1;audio_pending<=0;
     end else if(frame_pending) begin frame_index<=0;state<=7;frame_pending<=0;end
    end
    1:begin coefficient<=coeff(index[4:1]);state<=2;end
    2:begin delta<=$signed(index[0] ? clean_r : clean_l)-$signed(old_filter);state<=3;end
    3:begin product<=delta*$signed({1'b0,coefficient});state<=4;end
    4:begin next_filter<=old_filter+(product>>>8);state<=5;end
    5:begin
     band<=$signed(next_filter)-$signed(index[0] ? previous_r : previous_l);
     if(index[0]) previous_r<=next_filter;else previous_l<=next_filter;
     state<=6;
    end
    6:if(index==23) state<=0;else begin index<=index+1'b1;state<=1;end
    // Vblank precedes active video; the sweep completes within 220 clocks.
    7:state<=8;
    8:begin frame_old<=display[frame_index];state<=9;end
    9:begin
     if(silent) display[frame_index]<=0;
     else if(frame_peak>=frame_old || frame_old<=7'd4) display[frame_index]<=frame_peak;
     else display[frame_index]<=frame_peak>frame_old-7'd4 ? frame_peak : frame_old-7'd4;
     if(frame_index==23) state<=0;else begin frame_index<=frame_index+1'b1;state<=7;end
    end
   endcase
  end
 end
endmodule
