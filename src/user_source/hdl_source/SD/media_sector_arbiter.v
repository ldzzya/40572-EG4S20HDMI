// One physical sector at a time. Audio gets priority at sector boundaries.
// Requests are levels, released by each client on its first response byte.
module media_sector_arbiter #(parameter TIMEOUT=50000000)(
 input clk,rst,input [2:0] req,input [95:0] addr,
 output [7:0] data,output [2:0] valid,done,
 output reg sd_req,output reg [31:0] sd_addr,
 input [7:0] sd_data,input sd_valid,sd_done
);
 reg busy;reg [1:0] owner;reg [31:0] timer;reg timeout_pulse;
 assign data=sd_data;
 assign valid=busy && sd_valid ? (3'b001<<owner) : 0;
 assign done=(busy && sd_done) || timeout_pulse ? (3'b001<<owner) : 0;
 always @(posedge clk or posedge rst) begin
  if(rst) begin busy<=0;owner<=0;sd_req<=0;sd_addr<=0;timer<=0;timeout_pulse<=0;end
  else begin
   timeout_pulse<=0;
   if(!busy && !timeout_pulse) begin
    timer<=0;
    if(req!=0) begin
     busy<=1;sd_req<=1;
     if(req[2]) begin owner<=2;sd_addr<=addr[95:64];end
     else if(req[1]) begin owner<=1;sd_addr<=addr[63:32];end
     else begin owner<=0;sd_addr<=addr[31:0];end
    end
   end else if(busy) begin
    if(sd_valid) begin sd_req<=0;timer<=0;end
    else timer<=timer+1'b1;
    if(sd_done) begin sd_req<=0;busy<=0;end
    else if(timer==TIMEOUT-1) begin sd_req<=0;busy<=0;timeout_pulse<=1;end
   end
  end
 end
endmodule
