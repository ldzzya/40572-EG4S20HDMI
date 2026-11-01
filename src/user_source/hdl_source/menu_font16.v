// Explicit 8192-pixel banks avoid synthesis padding partial large ROMs.
module menu_font16(input clk,input [8:0] character,input big_font,input [4:0] gx,gy,output [1:0] coverage);
reg [15:0] title_base;
always @* case(character)
9'd32:title_base=16'd0;
9'd38:title_base=16'd512;
9'd45:title_base=16'd1024;
9'd65:title_base=16'd1536;
9'd67:title_base=16'd2048;
9'd68:title_base=16'd2560;
9'd70:title_base=16'd3072;
9'd71:title_base=16'd3584;
9'd76:title_base=16'd4096;
9'd77:title_base=16'd4608;
9'd80:title_base=16'd5120;
9'd83:title_base=16'd5632;
9'd97:title_base=16'd6144;
9'd98:title_base=16'd6656;
9'd99:title_base=16'd7168;
9'd100:title_base=16'd7680;
9'd101:title_base=16'd8192;
9'd103:title_base=16'd8704;
9'd104:title_base=16'd9216;
9'd105:title_base=16'd9728;
9'd107:title_base=16'd10240;
9'd108:title_base=16'd10752;
9'd109:title_base=16'd11264;
9'd110:title_base=16'd11776;
9'd111:title_base=16'd12288;
9'd112:title_base=16'd12800;
9'd115:title_base=16'd13312;
9'd116:title_base=16'd13824;
9'd117:title_base=16'd14336;
9'd121:title_base=16'd14848;
9'd140:title_base=16'd15360;
9'd145:title_base=16'd16384;
9'd148:title_base=16'd17408;
9'd174:title_base=16'd18432;
9'd176:title_base=16'd19456;
9'd177:title_base=16'd20480;
9'd186:title_base=16'd21504;
9'd190:title_base=16'd22528;
9'd195:title_base=16'd23552;
9'd206:title_base=16'd24576;
9'd208:title_base=16'd25600;
9'd216:title_base=16'd26624;
9'd235:title_base=16'd27648;
9'd238:title_base=16'd28672;
9'd240:title_base=16'd29696;
9'd243:title_base=16'd30720;
9'd246:title_base=16'd31744;
9'd252:title_base=16'd32768;
9'd254:title_base=16'd33792;
9'd279:title_base=16'd34816;
9'd282:title_base=16'd35840;
default:title_base=0;endcase
wire [6:0] latin_index=character-32;wire [7:0] chinese_index=character-80;
wire [15:0] body_addr=character<128 ? {1'b0,latin_index,gy[3:0],gx[2:0]} : {chinese_index,gy[3:0],gx[3:0]};
wire [15:0] title_addr=character<128 ? {title_base[15:9],gy,gx[3:0]} : {title_base[15:10],gy,gx};
reg big_q;always @(posedge clk) big_q<=big_font;
reg [1:0] body_0[0:8191];reg [1:0] body_q0;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_0.hex",body_0);
`else
initial $readmemh("ui_body_0.hex",body_0);
`endif
always @(posedge clk) body_q0<=body_0[body_addr[12:0]];
reg [1:0] body_1[0:8191];reg [1:0] body_q1;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_1.hex",body_1);
`else
initial $readmemh("ui_body_1.hex",body_1);
`endif
always @(posedge clk) body_q1<=body_1[body_addr[12:0]];
reg [1:0] body_2[0:8191];reg [1:0] body_q2;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_2.hex",body_2);
`else
initial $readmemh("ui_body_2.hex",body_2);
`endif
always @(posedge clk) body_q2<=body_2[body_addr[12:0]];
reg [1:0] body_3[0:8191];reg [1:0] body_q3;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_3.hex",body_3);
`else
initial $readmemh("ui_body_3.hex",body_3);
`endif
always @(posedge clk) body_q3<=body_3[body_addr[12:0]];
reg [1:0] body_4[0:8191];reg [1:0] body_q4;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_4.hex",body_4);
`else
initial $readmemh("ui_body_4.hex",body_4);
`endif
always @(posedge clk) body_q4<=body_4[body_addr[12:0]];
reg [1:0] body_5[0:8191];reg [1:0] body_q5;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_5.hex",body_5);
`else
initial $readmemh("ui_body_5.hex",body_5);
`endif
always @(posedge clk) body_q5<=body_5[body_addr[12:0]];
reg [1:0] body_6[0:8191];reg [1:0] body_q6;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_body_6.hex",body_6);
`else
initial $readmemh("ui_body_6.hex",body_6);
`endif
always @(posedge clk) body_q6<=body_6[body_addr[12:0]];
reg [2:0] body_bank;always @(posedge clk) body_bank<=body_addr[15:13];
reg [1:0] body_pixel;always @* case(body_bank)
3'd0:body_pixel=body_q0;
3'd1:body_pixel=body_q1;
3'd2:body_pixel=body_q2;
3'd3:body_pixel=body_q3;
3'd4:body_pixel=body_q4;
3'd5:body_pixel=body_q5;
3'd6:body_pixel=body_q6;
default:body_pixel=0;endcase
reg [1:0] title_0[0:8191];reg [1:0] title_q0;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_title_0.hex",title_0);
`else
initial $readmemh("ui_title_0.hex",title_0);
`endif
always @(posedge clk) title_q0<=title_0[title_addr[12:0]];
reg [1:0] title_1[0:8191];reg [1:0] title_q1;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_title_1.hex",title_1);
`else
initial $readmemh("ui_title_1.hex",title_1);
`endif
always @(posedge clk) title_q1<=title_1[title_addr[12:0]];
reg [1:0] title_2[0:8191];reg [1:0] title_q2;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_title_2.hex",title_2);
`else
initial $readmemh("ui_title_2.hex",title_2);
`endif
always @(posedge clk) title_q2<=title_2[title_addr[12:0]];
reg [1:0] title_3[0:8191];reg [1:0] title_q3;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_title_3.hex",title_3);
`else
initial $readmemh("ui_title_3.hex",title_3);
`endif
always @(posedge clk) title_q3<=title_3[title_addr[12:0]];
reg [1:0] title_4[0:8191];reg [1:0] title_q4;
`ifdef UI_SIMULATION
initial $readmemh("src/user_source/hdl_source/ui_title_4.hex",title_4);
`else
initial $readmemh("ui_title_4.hex",title_4);
`endif
always @(posedge clk) title_q4<=title_4[title_addr[12:0]];
reg [2:0] title_bank;always @(posedge clk) title_bank<=title_addr[15:13];
reg [1:0] title_pixel;always @* case(title_bank)
3'd0:title_pixel=title_q0;
3'd1:title_pixel=title_q1;
3'd2:title_pixel=title_q2;
3'd3:title_pixel=title_q3;
3'd4:title_pixel=title_q4;
default:title_pixel=0;endcase
assign coverage=big_q ? title_pixel : body_pixel;
endmodule