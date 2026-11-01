// One pixel per requested clock, including across line blanking. The FIFO has
// a one-clock registered read. Prefetch during blanking hides that latency.
module rgb24_unpack(input clk,rst,fifo_empty,output fifo_re,
 input [31:0] fifo_data,input pixel_req,output reg [23:0] pixel,
 output reg underflow);
 // Nine bytes cover a 32-bit word in flight plus five queued bytes.
 // Keeping a twelve-byte barrel shifter here needlessly widened every mux.
 reg [71:0] bytes;
 reg [3:0] count;
 reg pending;
 wire pop=pixel_req && count>=3;
 wire [3:0] remaining=count-(pop ? 4'd3 : 4'd0);
 wire [3:0] next_count=remaining+(pending ? 4'd4 : 4'd0);
 wire [71:0] shifted=pop ? {24'd0,bytes[71:24]} : bytes;
 reg [71:0] appended;
 always @* case(remaining)
  0:appended={40'd0,fifo_data};
  1:appended={32'd0,fifo_data,8'd0};
  2:appended={24'd0,fifo_data,16'd0};
  3:appended={16'd0,fifo_data,24'd0};
  4:appended={8'd0,fifo_data,32'd0};
  default:appended={fifo_data,40'd0};
 endcase
 assign fifo_re=!rst && !fifo_empty && next_count<=5;
 always @(posedge clk or posedge rst) begin
  if(rst) begin bytes<=0;count<=0;pending<=0;pixel<=0;underflow<=0;end
  else begin
   pending<=fifo_re;
   count<=next_count;
   bytes<=shifted | (pending ? appended : 72'd0);
   if(pixel_req) begin
    pixel<=pop ? bytes[23:0] : 24'd0;
    if(!pop)underflow<=1;
   end
  end
 end
endmodule
