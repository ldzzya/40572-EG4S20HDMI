`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: anlgoic
// Author: 	xg 
// description:  top module
//////////////////////////////////////////////////////////////////////////////////
`define DEBUG
`include "global_def.v"
module sdram(
    output [3:0] align_status,
    output [7:0] align_detail,
    `ifdef SIMULATION
	output					SDRAM_CLK,
	output					SDR_CKE,
	output					SDR_RAS,
	output					SDR_CAS,
	output					SDR_WE,
	output	[`BA_WIDTH-1:0]	SDR_BA,
	output	[`ROW_WIDTH-1:0]SDR_ADDR,
	output	[`DM_WIDTH-1:0]	SDR_DM,
	inout	[`DATA_WIDTH-1:0]	SDR_DQ,	
	`endif
    input   					Clk,
    input						Clk_sft,
    input						Rst,
    output 						Sdr_init_done,
    output						Sdr_init_ref_vld,
    output						Sdr_busy,
    input						App_wr_en,
	input [`ADDR_WIDTH-1:0]		App_wr_addr,  	
	input [`DM_WIDTH-1:0]		App_wr_dm,
	input [`DATA_WIDTH-1:0]		App_wr_din,	//synthesis keep
    input 						App_rd_en,
	input [`ADDR_WIDTH-1:0]		App_rd_addr,
	output 						Sdr_rd_en,
	output [`DATA_WIDTH-1:0]	Sdr_rd_dout	//synthesis keep
);
`ifndef SIMULATION
wire  			SDRAM_CLK;
wire 			SDR_RAS;
wire  			SDR_CAS;
wire  			SDR_WE;
wire  [`BA_WIDTH-1:0]	SDR_BA; 
wire  [`ROW_WIDTH-1:0]	SDR_ADDR;
wire  [`DATA_WIDTH-1:0]	SDR_DQ ;
wire  [`DM_WIDTH-1:0]	SDR_DM; 
`endif
// Keep physical controller hierarchy/pins unchanged; only adapt its stream.
wire raw_init,raw_busy,raw_valid,pipeline_busy;
wire wr,rd;wire [20:0] wa,ra;wire [31:0] wd,rd_data;wire [3:0] mask;
sdram_stream_align aligner(.clk(Clk),.rst(Rst),.init_done(raw_init),
 .refresh_busy(Sdr_init_ref_vld),.controller_busy(raw_busy),
 .write_en(App_wr_en),.write_addr(App_wr_addr),.write_data(App_wr_din),.write_mask(App_wr_dm),
 .read_en(App_rd_en),.read_addr(App_rd_addr),.ready(Sdr_init_done),.status(align_status),
 .detail(align_detail),.pipeline_busy(pipeline_busy),
 .memory_write_en(wr),.memory_write_addr(wa),.memory_write_data(wd),.memory_write_mask(mask),
 .memory_read_en(rd),.memory_read_addr(ra),.memory_read_valid(raw_valid),.memory_read_data(rd_data),
 .read_valid(Sdr_rd_en),.read_data(Sdr_rd_dout));
assign Sdr_busy=raw_busy || pipeline_busy || !Sdr_init_done;
sdr_as_ram  #( .self_refresh_open(1'b1))
	u2_ram( 
		.Sdr_clk(Clk),
		.Sdr_clk_sft(Clk_sft),
		.Rst(Rst),
		.Sdr_init_done(raw_init),
		.Sdr_init_ref_vld(Sdr_init_ref_vld),
		.Sdr_busy(raw_busy),
		.App_ref_req(1'b0),
        .App_wr_en(wr), 
        .App_wr_addr(wa),  	
		.App_wr_dm(mask),
		.App_wr_din(wd),
		.App_rd_en(rd),
		.App_rd_addr(ra),
		.Sdr_rd_en	(raw_valid),
		.Sdr_rd_dout(rd_data),
		.SDRAM_CLK(SDRAM_CLK),
		.SDR_RAS(SDR_RAS),
		.SDR_CAS(SDR_CAS),
		.SDR_WE(SDR_WE),
		.SDR_BA(SDR_BA),
		.SDR_ADDR(SDR_ADDR),
		.SDR_DM(SDR_DM),
		.SDR_DQ(SDR_DQ)	
	);
assign SDR_CKE=1'b1;
//`ifndef SIMULATION
	EG_PHY_SDRAM_2M_32 sdram(
		.clk(SDRAM_CLK),
		.ras_n(SDR_RAS),
		.cas_n(SDR_CAS),
		.we_n(SDR_WE),
		.addr(SDR_ADDR[10:0]),
		.ba(SDR_BA),
		.dq(SDR_DQ),
		.cs_n(1'b0),
		.dm0(SDR_DM[0]),
		.dm1(SDR_DM[1]),
		.dm2(SDR_DM[2]),
		.dm3(SDR_DM[3]),
		.cke(1'b1)
		);
//`endif
endmodule 
