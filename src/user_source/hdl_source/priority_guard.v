// SW1 high selects numeric 1.bmp/1.wav. Independent of KEY1 reset so a
// reset-button press cannot escape the lock. FPGA configuration initializes
// these registers; no generated/gated clocks are used.
module priority_guard #(parameter DEBOUNCE_CYCLES=250000)(
 input clk,input switch_1,input [3:0] buttons_n,
 output reg locked=0,output [3:0] allowed_buttons_n
);
 localparam W=$clog2(DEBOUNCE_CYCLES+1);
 reg [1:0] switch_sync=0;
 reg [3:0] buttons_meta=15,buttons_sync=15;
 reg [W-1:0] stable_count=0;
 reg armed=0;
 assign allowed_buttons_n=(locked || !armed) ? 4'b1111 : buttons_n;
 always @(posedge clk) begin
  switch_sync<={switch_sync[0],switch_1};
  buttons_meta<=buttons_n;buttons_sync<=buttons_meta;
  if(switch_sync[1]!=locked) begin
   if(stable_count==DEBOUNCE_CYCLES-1) begin locked<=switch_sync[1];stable_count<=0;end
   else stable_count<=stable_count+1'b1;
  end else if(!locked && !armed && buttons_sync==15) begin
   if(stable_count==DEBOUNCE_CYCLES-1) begin armed<=1;stable_count<=0;end
   else stable_count<=stable_count+1'b1;
  end else stable_count<=0;
  // A key held across unlock must be released before any action is possible.
  if(locked) armed<=0;
  // Do not reuse a partially elapsed key-release interval for a switch edge.
  if(switch_sync[0]!=switch_sync[1]) stable_count<=0;
 end
endmodule
