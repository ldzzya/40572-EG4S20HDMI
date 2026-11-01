// Lossless packing: four RGB24 pixels become three 32-bit SDRAM words.
// A frame/row must contain a multiple of four pixels. The source respects the
// parent FIFO's ready signal; its spare capacity covers this register stage.
module rgb24_pack(input clk,rst,pixel_valid,input [23:0] pixel,
 output reg word_valid,output reg [31:0] word_data);
 reg [1:0] phase;
 reg [23:0] tail;
 always @(posedge clk or posedge rst) begin
  if(rst) begin phase<=0;tail<=0;word_valid<=0;word_data<=0;end
  else begin
   word_valid<=0;
   if(pixel_valid) begin
    phase<=phase+1'b1;
    case(phase)
     0:tail<=pixel;
     1:begin word_data<={pixel[7:0],tail};tail<={8'd0,pixel[23:8]};word_valid<=1;end
     2:begin word_data<={pixel[15:0],tail[15:0]};tail<={16'd0,pixel[23:16]};word_valid<=1;end
     3:begin word_data<={pixel,tail[7:0]};tail<=0;word_valid<=1;end
    endcase
   end
  end
 end
endmodule
