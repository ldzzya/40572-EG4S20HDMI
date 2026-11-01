module tone_pcm_48k(input clk,rst,output reg valid,output reg [23:0] left,right);
 reg [24:0] rate_acc;
 reg [31:0] phase;
 reg [14:0] hold_count;
 reg [2:0] note;
 reg [31:0] increment;
 reg signed [23:0] sample;
 always @* case(note)
  0:increment=23409862;1:increment=26276681;2:increment=29494578;3:increment=31248410;
  4:increment=35075155;5:increment=39370534;6:increment=44191930;default:increment=46819716;
 endcase
 always @* case(phase[31:26])
  6'd0:sample=24'sd0;
  6'd1:sample=24'sd196034;
  6'd2:sample=24'sd390181;
  6'd3:sample=24'sd580569;
  6'd4:sample=24'sd765367;
  6'd5:sample=24'sd942793;
  6'd6:sample=24'sd1111140;
  6'd7:sample=24'sd1268787;
  6'd8:sample=24'sd1414214;
  6'd9:sample=24'sd1546021;
  6'd10:sample=24'sd1662939;
  6'd11:sample=24'sd1763843;
  6'd12:sample=24'sd1847759;
  6'd13:sample=24'sd1913881;
  6'd14:sample=24'sd1961571;
  6'd15:sample=24'sd1990369;
  6'd16:sample=24'sd2000000;
  6'd17:sample=24'sd1990369;
  6'd18:sample=24'sd1961571;
  6'd19:sample=24'sd1913881;
  6'd20:sample=24'sd1847759;
  6'd21:sample=24'sd1763843;
  6'd22:sample=24'sd1662939;
  6'd23:sample=24'sd1546021;
  6'd24:sample=24'sd1414214;
  6'd25:sample=24'sd1268787;
  6'd26:sample=24'sd1111140;
  6'd27:sample=24'sd942793;
  6'd28:sample=24'sd765367;
  6'd29:sample=24'sd580569;
  6'd30:sample=24'sd390181;
  6'd31:sample=24'sd196034;
  6'd32:sample=24'sd0;
  6'd33:sample=-24'sd196034;
  6'd34:sample=-24'sd390181;
  6'd35:sample=-24'sd580569;
  6'd36:sample=-24'sd765367;
  6'd37:sample=-24'sd942793;
  6'd38:sample=-24'sd1111140;
  6'd39:sample=-24'sd1268787;
  6'd40:sample=-24'sd1414214;
  6'd41:sample=-24'sd1546021;
  6'd42:sample=-24'sd1662939;
  6'd43:sample=-24'sd1763843;
  6'd44:sample=-24'sd1847759;
  6'd45:sample=-24'sd1913881;
  6'd46:sample=-24'sd1961571;
  6'd47:sample=-24'sd1990369;
  6'd48:sample=-24'sd2000000;
  6'd49:sample=-24'sd1990369;
  6'd50:sample=-24'sd1961571;
  6'd51:sample=-24'sd1913881;
  6'd52:sample=-24'sd1847759;
  6'd53:sample=-24'sd1763843;
  6'd54:sample=-24'sd1662939;
  6'd55:sample=-24'sd1546021;
  6'd56:sample=-24'sd1414214;
  6'd57:sample=-24'sd1268787;
  6'd58:sample=-24'sd1111140;
  6'd59:sample=-24'sd942793;
  6'd60:sample=-24'sd765367;
  6'd61:sample=-24'sd580569;
  6'd62:sample=-24'sd390181;
  6'd63:sample=-24'sd196034;
 endcase
 always @(posedge clk or posedge rst) begin
  if(rst) begin rate_acc<=0;phase<=0;hold_count<=0;note<=0;valid<=0;left<=0;right<=0;end
  else begin
   valid<=0;
   if(rate_acc>=25000000-48000) begin
    rate_acc<=rate_acc+48000-25000000;valid<=1;left<=sample;right<=sample;
    phase<=phase+increment;
    if(hold_count==23999) begin hold_count<=0;note<=note+1'b1;end
    else hold_count<=hold_count+1'b1;
   end else rate_acc<=rate_acc+48000;
  end
 end
endmodule
