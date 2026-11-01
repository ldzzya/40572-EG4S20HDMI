// A 2048-pixel RGB24 row in two native 32K RAMs, with one-cycle read latency.
// The unused upper byte is trimmed by the primitive's byte mask.
module rgb_row_ram(input clk,we,input [10:0] wa,ra,input [23:0] wd,output [23:0] rd);
`ifdef UI_SIMULATION
 reg [23:0] memory[0:2047];reg [23:0] q;
 always @(posedge clk) begin if(we) memory[wa]<=wd;q<=memory[ra];end
 assign rd=q;
`else
 wire [15:0] high;
 EG_PHY_BRAM32K #(.MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG")) low_ram(
  .clka(clk),.rsta(1'b0),.csa(we),.wea(we),.addra(wa),.dia(wd[15:0]),
  .bytea(1'b0),.bytewea(1'b0),.ocea(1'b1),.doa(),
  .clkb(clk),.rstb(1'b0),.csb(1'b1),.web(1'b0),.addrb(ra),.dib(16'd0),
  .byteb(1'b0),.byteweb(1'b0),.oceb(1'b1),.dob(rd[15:0]));
 EG_PHY_BRAM32K #(.MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
  .REGMODE_A("NOREG"),.REGMODE_B("NOREG")) high_ram(
  .clka(clk),.rsta(1'b0),.csa(we),.wea(we),.addra(wa),.dia({8'd0,wd[23:16]}),
  .bytea(1'b0),.bytewea(1'b1),.ocea(1'b1),.doa(),
  .clkb(clk),.rstb(1'b0),.csb(1'b1),.web(1'b0),.addrb(ra),.dib(16'd0),
  .byteb(1'b0),.byteweb(1'b0),.oceb(1'b1),.dob(high));
 assign rd[23:16]=high[7:0];
`endif
endmodule
