// A cropped warning banner uses a 640x40 RGBA2222 cache, displayed at integer
// 2x scale. Seven native RAM32K blocks store 12,800 paired mask words.
// Input is the complete bottom-up BMP stream; RGB is stored separately in SDRAM.
module warning_layer_cache(input clk,rst,load_reset,load_enable,write_en,
 input [7:0] write_mask,input [9:0] strip_top,input show,vs,de,
 input [23:0] rgb,output reg out_vs,out_de,output reg [23:0] out_rgb,
 output [7:0] mask);
 reg [10:0] wx,rx;
 reg [9:0] wy,ry,top;
 reg old_vs;
 reg [7:0] first;
 wire [9:0] write_screen_y=10'd719-wy;
 wire [9:0] write_rel=write_screen_y-strip_top;
 wire take=load_enable && write_en && write_screen_y>=strip_top && write_rel<80 && !wx[0] && !write_rel[0];
 wire [13:0] wa=(write_rel[6:1]<<8)+(write_rel[6:1]<<6)+(wx>>2);
 wire [9:0] read_rel=ry-top;
 wire in_strip=show && de && ry>=top && read_rel<80;
 wire [13:0] ra=(read_rel[6:1]<<8)+(read_rel[6:1]<<6)+(rx>>2);
 wire we=take && wx[1];
 wire [15:0] wd={write_mask,first};
 wire [15:0] rd;
 reg high_byte,valid;
 always @(posedge clk or posedge rst) begin
  if(rst) begin wx<=0;wy<=0;rx<=0;ry<=0;top<=0;old_vs<=0;first<=0;
   out_vs<=0;out_de<=0;out_rgb<=0;high_byte<=0;valid<=0;end
  else begin
   if(load_reset)begin wx<=0;wy<=0;if(load_enable)top<=strip_top;end
   else if(write_en)begin
    if(wx==1279)begin wx<=0;wy<=wy+1'b1;end else wx<=wx+1'b1;
   end
   if(take && !wx[1])first<=write_mask;
   old_vs<=vs;
   if(vs && !old_vs)begin rx<=0;ry<=0;end
   else if(de)begin if(rx==1279)begin rx<=0;ry<=ry+1'b1;end else rx<=rx+1'b1;end
   out_vs<=vs;out_de<=de;out_rgb<=rgb;
   high_byte<=rx[1];valid<=in_strip;
  end
 end
 assign mask=valid ? (high_byte ? rd[15:8] : rd[7:0]) : 8'd0;
`ifdef UI_SIMULATION
 reg [15:0] memory[0:12799];reg [15:0] q;
 always @(posedge clk) begin if(we)memory[wa]<=wd;q<=memory[ra];end
 assign rd=q;
`else
 wire [15:0] q[0:6];reg [2:0] bank;
 always @(posedge clk)bank<=ra[13:11];
 genvar i;generate for(i=0;i<7;i=i+1)begin:ram
  EG_PHY_BRAM32K #(.MODE("DP16K"),.DATA_WIDTH_A("16"),.DATA_WIDTH_B("16"),
   .REGMODE_A("NOREG"),.REGMODE_B("NOREG")) mem(
   .clka(clk),.rsta(1'b0),.csa(we && wa[13:11]==i),.wea(we),.addra(wa[10:0]),.dia(wd),
   .bytea(1'b0),.bytewea(1'b0),.ocea(1'b1),.doa(),
   .clkb(clk),.rstb(1'b0),.csb(1'b1),.web(1'b0),.addrb(ra[10:0]),.dib(16'd0),
   .byteb(1'b0),.byteweb(1'b0),.oceb(1'b1),.dob(q[i]));
 end endgenerate
 assign rd=q[bank];
`endif
endmodule
