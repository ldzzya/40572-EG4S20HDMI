// Twenty 5-percent steps. Slew the gain in the sample domain to avoid clicks.
// Both HDMI and the visualizer consume these exact post-gain PCM samples.
module audio_volume(input clk,rst,down,up,input in_valid,
 input signed [23:0] in_left,in_right,output reg out_valid,
 output reg signed [23:0] out_left,out_right,output reg [4:0] level,input mute);
 reg [8:0] current_gain,sample_gain;reg sample_valid;
 reg signed [23:0] sample_left,sample_right;
 wire [12:0] target_product=level*13'd205;
 wire [8:0] target_gain=mute ? 9'd0 : target_product[12:4];
 wire signed [33:0] left_product=$signed(sample_left)*$signed({1'b0,sample_gain});
 wire signed [33:0] right_product=$signed(sample_right)*$signed({1'b0,sample_gain});
 always @(posedge clk or posedge rst) begin
  if(rst) begin level<=20;current_gain<=0;sample_gain<=0;sample_valid<=0;sample_left<=0;sample_right<=0;out_valid<=0;out_left<=0;out_right<=0;end
  else begin
   if(up && !down && level<20) level<=level+1'b1;
   else if(down && !up && level>0) level<=level-1'b1;
   sample_valid<=in_valid;out_valid<=sample_valid;
   if(sample_valid) begin out_left<=left_product>>>8;out_right<=right_product>>>8;end
   if(in_valid) begin
    if(current_gain<target_gain) current_gain<=current_gain+1'b1;
    else if(current_gain>target_gain) current_gain<=current_gain-1'b1;
    sample_left<=in_left;sample_right<=in_right;sample_gain<=current_gain;
   end
  end
 end
endmodule
