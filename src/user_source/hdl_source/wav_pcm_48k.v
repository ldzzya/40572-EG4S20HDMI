// Stereo PCM queue and fixed 48 kHz output. 44.1 kHz uses exact 147/160 phase
// progression with linear interpolation; neither playback speed nor pitch changes.
module wav_pcm_48k #(parameter CLOCK_HZ=25000000)(
 input clk,rst,flush,enable,rate_44100,
 input push,input [23:0] in_left,in_right,output room,
 output reg valid,output reg [23:0] left,right,output reg underrun,
 output [10:0] buffered,input pause_playback,input checkpoint,restore_context,output sample_taken
);
 reg [47:0] mem[0:1023];reg [47:0] q;
 reg [9:0] wp,rp;reg [10:0] count;
 reg [31:0] clock_phase;
 reg [2:0] state;reg [7:0] phase;
 reg signed [23:0] al,ar,bl,br;
 reg [2:0] saved_state;reg [7:0] saved_phase,saved_coefficient,coefficient_reg;
 reg [95:0] saved_samples;reg restore_pending;
 wire take;
 assign sample_taken=take && !flush && !rst;
 wire paused=pause_playback===1'b1;
 wire tick=clock_phase>=CLOCK_HZ-48000;
 wire advance=!rate_44100 || phase>=13;
 assign take=(state==1 || state==3 || (state==4 && tick && advance)) && count!=0 && enable && !paused && !restore_pending;
 wire put=push && count<1024;
 assign room=count<1000;assign buffered=count;
 // Compute the next resampling weight when phase advances, leaving a
 // complete sample interval for the registered coefficient to settle.
 function [7:0] phase_weight;input [7:0] p;begin case(p)
  8'd0:phase_weight=8'd0;
  8'd1:phase_weight=8'd2;
  8'd2:phase_weight=8'd3;
  8'd3:phase_weight=8'd5;
  8'd4:phase_weight=8'd6;
  8'd5:phase_weight=8'd8;
  8'd6:phase_weight=8'd10;
  8'd7:phase_weight=8'd11;
  8'd8:phase_weight=8'd13;
  8'd9:phase_weight=8'd14;
  8'd10:phase_weight=8'd16;
  8'd11:phase_weight=8'd18;
  8'd12:phase_weight=8'd19;
  8'd13:phase_weight=8'd21;
  8'd14:phase_weight=8'd22;
  8'd15:phase_weight=8'd24;
  8'd16:phase_weight=8'd26;
  8'd17:phase_weight=8'd27;
  8'd18:phase_weight=8'd29;
  8'd19:phase_weight=8'd30;
  8'd20:phase_weight=8'd32;
  8'd21:phase_weight=8'd34;
  8'd22:phase_weight=8'd35;
  8'd23:phase_weight=8'd37;
  8'd24:phase_weight=8'd38;
  8'd25:phase_weight=8'd40;
  8'd26:phase_weight=8'd42;
  8'd27:phase_weight=8'd43;
  8'd28:phase_weight=8'd45;
  8'd29:phase_weight=8'd46;
  8'd30:phase_weight=8'd48;
  8'd31:phase_weight=8'd50;
  8'd32:phase_weight=8'd51;
  8'd33:phase_weight=8'd53;
  8'd34:phase_weight=8'd54;
  8'd35:phase_weight=8'd56;
  8'd36:phase_weight=8'd58;
  8'd37:phase_weight=8'd59;
  8'd38:phase_weight=8'd61;
  8'd39:phase_weight=8'd62;
  8'd40:phase_weight=8'd64;
  8'd41:phase_weight=8'd66;
  8'd42:phase_weight=8'd67;
  8'd43:phase_weight=8'd69;
  8'd44:phase_weight=8'd70;
  8'd45:phase_weight=8'd72;
  8'd46:phase_weight=8'd74;
  8'd47:phase_weight=8'd75;
  8'd48:phase_weight=8'd77;
  8'd49:phase_weight=8'd78;
  8'd50:phase_weight=8'd80;
  8'd51:phase_weight=8'd82;
  8'd52:phase_weight=8'd83;
  8'd53:phase_weight=8'd85;
  8'd54:phase_weight=8'd86;
  8'd55:phase_weight=8'd88;
  8'd56:phase_weight=8'd90;
  8'd57:phase_weight=8'd91;
  8'd58:phase_weight=8'd93;
  8'd59:phase_weight=8'd94;
  8'd60:phase_weight=8'd96;
  8'd61:phase_weight=8'd98;
  8'd62:phase_weight=8'd99;
  8'd63:phase_weight=8'd101;
  8'd64:phase_weight=8'd102;
  8'd65:phase_weight=8'd104;
  8'd66:phase_weight=8'd106;
  8'd67:phase_weight=8'd107;
  8'd68:phase_weight=8'd109;
  8'd69:phase_weight=8'd110;
  8'd70:phase_weight=8'd112;
  8'd71:phase_weight=8'd114;
  8'd72:phase_weight=8'd115;
  8'd73:phase_weight=8'd117;
  8'd74:phase_weight=8'd118;
  8'd75:phase_weight=8'd120;
  8'd76:phase_weight=8'd122;
  8'd77:phase_weight=8'd123;
  8'd78:phase_weight=8'd125;
  8'd79:phase_weight=8'd126;
  8'd80:phase_weight=8'd128;
  8'd81:phase_weight=8'd130;
  8'd82:phase_weight=8'd131;
  8'd83:phase_weight=8'd133;
  8'd84:phase_weight=8'd134;
  8'd85:phase_weight=8'd136;
  8'd86:phase_weight=8'd138;
  8'd87:phase_weight=8'd139;
  8'd88:phase_weight=8'd141;
  8'd89:phase_weight=8'd142;
  8'd90:phase_weight=8'd144;
  8'd91:phase_weight=8'd146;
  8'd92:phase_weight=8'd147;
  8'd93:phase_weight=8'd149;
  8'd94:phase_weight=8'd150;
  8'd95:phase_weight=8'd152;
  8'd96:phase_weight=8'd154;
  8'd97:phase_weight=8'd155;
  8'd98:phase_weight=8'd157;
  8'd99:phase_weight=8'd158;
  8'd100:phase_weight=8'd160;
  8'd101:phase_weight=8'd162;
  8'd102:phase_weight=8'd163;
  8'd103:phase_weight=8'd165;
  8'd104:phase_weight=8'd166;
  8'd105:phase_weight=8'd168;
  8'd106:phase_weight=8'd170;
  8'd107:phase_weight=8'd171;
  8'd108:phase_weight=8'd173;
  8'd109:phase_weight=8'd174;
  8'd110:phase_weight=8'd176;
  8'd111:phase_weight=8'd178;
  8'd112:phase_weight=8'd179;
  8'd113:phase_weight=8'd181;
  8'd114:phase_weight=8'd182;
  8'd115:phase_weight=8'd184;
  8'd116:phase_weight=8'd186;
  8'd117:phase_weight=8'd187;
  8'd118:phase_weight=8'd189;
  8'd119:phase_weight=8'd190;
  8'd120:phase_weight=8'd192;
  8'd121:phase_weight=8'd194;
  8'd122:phase_weight=8'd195;
  8'd123:phase_weight=8'd197;
  8'd124:phase_weight=8'd198;
  8'd125:phase_weight=8'd200;
  8'd126:phase_weight=8'd202;
  8'd127:phase_weight=8'd203;
  8'd128:phase_weight=8'd205;
  8'd129:phase_weight=8'd206;
  8'd130:phase_weight=8'd208;
  8'd131:phase_weight=8'd210;
  8'd132:phase_weight=8'd211;
  8'd133:phase_weight=8'd213;
  8'd134:phase_weight=8'd214;
  8'd135:phase_weight=8'd216;
  8'd136:phase_weight=8'd218;
  8'd137:phase_weight=8'd219;
  8'd138:phase_weight=8'd221;
  8'd139:phase_weight=8'd222;
  8'd140:phase_weight=8'd224;
  8'd141:phase_weight=8'd226;
  8'd142:phase_weight=8'd227;
  8'd143:phase_weight=8'd229;
  8'd144:phase_weight=8'd230;
  8'd145:phase_weight=8'd232;
  8'd146:phase_weight=8'd234;
  8'd147:phase_weight=8'd235;
  8'd148:phase_weight=8'd237;
  8'd149:phase_weight=8'd238;
  8'd150:phase_weight=8'd240;
  8'd151:phase_weight=8'd242;
  8'd152:phase_weight=8'd243;
  8'd153:phase_weight=8'd245;
  8'd154:phase_weight=8'd246;
  8'd155:phase_weight=8'd248;
  8'd156:phase_weight=8'd250;
  8'd157:phase_weight=8'd251;
  8'd158:phase_weight=8'd253;
  8'd159:phase_weight=8'd254;
  default:phase_weight=0;
 endcase end endfunction
 wire [7:0] next_phase=phase>=13 ? phase-8'd13 : phase+8'd147;
 wire [8:0] coefficient={1'b0,coefficient_reg};
 wire signed [24:0] dl=$signed({bl[23],bl})-$signed({al[23],al});
 wire signed [24:0] dr=$signed({br[23],br})-$signed({ar[23],ar});
 wire signed [34:0] ml=dl*$signed({1'b0,coefficient});
 wire signed [34:0] mr=dr*$signed({1'b0,coefficient});
 wire signed [34:0] il=$signed(al)+(ml>>>8),ir=$signed(ar)+(mr>>>8);
 always @(posedge clk) begin
  if(put && !rst && !flush) mem[wp]<={in_left,in_right};
  q<=mem[rp];
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   wp<=0;rp<=0;count<=0;clock_phase<=0;state<=0;phase<=0;coefficient_reg<=0;
   saved_state<=0;saved_phase<=0;saved_coefficient<=0;saved_samples<=0;restore_pending<=0;
   al<=0;ar<=0;bl<=0;br<=0;valid<=0;left<=0;right<=0;underrun<=0;
  end else begin
   valid<=tick;underrun<=0;
   if(checkpoint===1'b1) begin saved_state<=state;saved_phase<=phase;saved_coefficient<=coefficient_reg;saved_samples<={al,ar,bl,br};end
   if(restore_context===1'b1) restore_pending<=1;
   if(tick) clock_phase<=clock_phase-(CLOCK_HZ-48000);
   else clock_phase<=clock_phase+48000;
   if(flush) begin wp<=0;rp<=0;count<=0;state<=0;phase<=0;coefficient_reg<=0;left<=0;right<=0;restore_pending<=0;end
   else begin
    if(put) wp<=wp+1'b1;
    if(take) rp<=rp+1'b1;
    case({put,take}) 2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;endcase
    if(!enable) begin state<=0;phase<=0;coefficient_reg<=0;end
    else if(restore_pending) begin
     if(count>=256) begin state<=saved_state;phase<=saved_phase;coefficient_reg<=saved_coefficient;{al,ar,bl,br}<=saved_samples;restore_pending<=0;end
    end else if(!paused) case(state)
     0:if(count>=256) state<=1;
     1:if(take) begin al<=q[47:24];ar<=q[23:0];state<=2;end
     2:state<=3; // Synchronous RAM read settles after pointer advance.
     3:if(take) begin bl<=q[47:24];br<=q[23:0];state<=5;phase<=0;coefficient_reg<=0;end
     // The next 48kHz tick may be only one clock away. Allow the RAM read
     // after the second pointer advance to settle before consuming again.
     5:state<=4;
     4:if(tick) begin
      if(advance) begin
       if(take) begin al<=bl;ar<=br;bl<=q[47:24];br<=q[23:0];end
       else begin state<=0;phase<=0;coefficient_reg<=0;underrun<=1;end
      end
      if(rate_44100 && (!advance || take)) begin phase<=next_phase;coefficient_reg<=phase_weight(next_phase);end
     end
    endcase
    if(tick) begin
     if(enable && !paused && !restore_pending && state==4 && (!advance || take)) begin
      left<=rate_44100 ? il[23:0] : al;right<=rate_44100 ? ir[23:0] : ar;
     end else begin left<=0;right<=0;end
    end
   end
  end
 end
endmodule
