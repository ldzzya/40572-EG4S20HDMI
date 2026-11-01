`timescale 1ns/1ps
module tb_full_memory;
reg clk=0,memclk=0,sft=0,rst=1,rr=0,pr=0,wr=0,we=0;reg [23:0] pd=0;
always #6.734 clk=~clk;always #10.101 memclk=~memclk;always @(memclk)sft<=#8.84 memclk;
full_memory_probe dut();
function [23:0] pattern(input integer p);pattern=((p*65537)^(p>>5)^24'hbc9876)&24'hffffff;endfunction
function [31:0] word_value(input integer w);
reg [95:0] group;integer p;begin p=(w/3)*4;group={pattern(p+3),pattern(p+2),pattern(p+1),pattern(p)};
case(w%3)0:word_value=group[31:0];1:word_value=group[63:32];2:word_value=group[95:64];endcase end endfunction
integer i,j,x,y,index=0,cycles=0,writes=0;
always @(posedge clk) begin
 cycles=cycles+1;
 if(cycles%5000==0)begin $display("PROGRESS clocks=%d pixel=%d",cycles,index);$fflush();end
end
initial begin
force dut.\U3/aligner/clk =memclk;
force dut.\U3/aligner/rst =rst;
force dut.\U3/u2_ram/Sdr_clk_sft =sft;
force dut.\frame_read_write_m0/packer/pixel_valid =we;
force dut.\frame_read_write_m0/read_req =rr;
force dut.\frame_read_write_m0/unpacker/pixel_req =pr;
force dut.\frame_read_write_m0/write_clk =clk;
force dut.\presenter/active_buf =2'd0;
force dut.\sd_card_bmp_m0/bmp_read_m0/bmp_data =pd;
force dut.\sd_card_bmp_m0/bmp_read_m0/write_req =wr;
force dut.\sd_card_bmp_m0/write_buf_idx =2'd1;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/I_axis_s_valid ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_hdmi_edid_read_controller/O_iic_tx_valid ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_receiver_controller/I_rst ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/O_bit_tx_data_type_b1[1]_syn_68 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/O_bit_tx_data_type_b1[1]_syn_70 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_1 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_10 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_11 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_2 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_23 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_24 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_25 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_26 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_27 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_28 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_29 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_3 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_30 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_31 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_32 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_33 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_4 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_45 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_46 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_47 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_48 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_49 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_5 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_50 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_51 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_52 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_53 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_54 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_55 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_6 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_7 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_78 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_79 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_8 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_80 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_81 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_82 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_83 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_84 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_85 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_86 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_87 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_88 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_edid_wrapper/u_iic_master_wrapper/u_iic_transmitter_controller/u_iic_w11_d1024_fifo/u_logic_ramfifo_syn_9 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_assemble/I_island_period ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_assemble/S_island_packet_cnt ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/S_packet_cnt ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/I_fifo_wr_en ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_1 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_10 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_11 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_2 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_23 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_24 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_25 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_26 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_27 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_28 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_29 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_3 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_30 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_31 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_32 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_33 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_4 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_45 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_46 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_47 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_48 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_49 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_5 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_50 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_51 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_52 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_53 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_54 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_55 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_6 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_7 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_78 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_79 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_8 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_80 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_81 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_82 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_83 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_84 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_85 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_86 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_87 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_88 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_hdmi_island_data_gen/U_audio_sample_packet_2_channel/u_w96_d1024_fifo/u_logic_ramfifo_syn_9 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/I_fifo_rd_en ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/I_rst ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_1 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_10 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_11 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_2 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_23 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_24 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_25 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_26 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_27 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_28 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_29 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_3 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_30 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_31 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_32 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_33 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_4 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_45 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_46 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_47 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_48 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_49 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_5 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_50 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_51 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_52 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_53 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_54 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_55 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_6 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_7 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_78 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_79 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_8 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_80 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_81 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_82 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_83 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_84 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_85 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_86 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_87 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_88 ='0;
force dut.\u_hdmi_1_4b_transmitter_core_wrapper/u_hdmi_tx_controller_wrapper/u_video_axi_stream_receiver/u_w24_d1024_fifo/u_logic_ramfifo_syn_9 ='0;
for(i=0;i<5000;i=i+1)dut.\U3/sdram .mem.memory[i]=word_value(i);
repeat(12)@(negedge clk);rst=0;
repeat(10)@(negedge memclk);force dut.\U3/u2_ram/u1_init_ref/pwr_200ms_cnt =18'h20000;
repeat(2)@(negedge memclk);release dut.\U3/u2_ram/u1_init_ref/pwr_200ms_cnt ;
wait(dut.\U3/aligner/complete );if(dut.\U3/aligner/selected_w !==2 || dut.\U3/aligner/selected_r !==2 || dut.\U3/aligner/failed !==0) $fatal(1,"mapped calibration failed");$display("INIT ready");$fflush();repeat(20)@(negedge clk);
fork
begin
rr=1;repeat(20)@(negedge clk);rr=0;repeat(1000)@(negedge clk);
for(y=0;y<2;y=y+1)begin
 for(x=0;x<1280;x=x+1)begin
  pr=1;@(posedge clk);#1;
  if(dut.\frame_read_write_m0/unpacker/pixel !==pattern(index))$fatal(1,"full netlist RGB pixel=%d actual=%h expected=%h",index,dut.\frame_read_write_m0/unpacker/pixel ,pattern(index));
  index=index+1;@(negedge clk);
 end
 pr=0;repeat(370)@(negedge clk);
end
end
begin
repeat(1200)@(negedge clk);wr=1;repeat(20)@(negedge clk);wr=0;repeat(20)@(negedge clk);
for(j=0;j<1280;j=j+1)begin
 @(negedge clk);while(!dut.\sd_card_bmp_m0/bmp_read_m0/write_ready )@(negedge clk);
 we=1;pd=pattern(j);@(negedge clk);we=0;repeat(2)@(negedge clk);
end
repeat(2000)@(negedge clk);
// The normal full-frame transaction is deliberately incomplete. All except
// the final partial scheduling reserve must have reached SDRAM.
for(i=0;i<896;i=i+1)if(dut.\U3/sdram .mem.memory[691200+719*960+i]!==word_value(i))$fatal(1,"full netlist write word=%d actual=%h expected=%h",i,dut.\U3/sdram .mem.memory[691200+719*960+i],word_value(i));
end
join
$display("PASS aligned full-project memory cone: exact RGB read and concurrent vertical-flip writes");$finish;
end
initial begin #300000;$fatal(1,"full memory timeout index=%d",index);end
endmodule
module EG_PHY_SDRAM_2M_32(input clk,ras_n,cas_n,we_n,input [10:0] addr,input [1:0] ba,inout [31:0] dq,
 input cs_n,dm0,dm1,dm2,dm3,cke);
sdram_model mem(.clk(clk),.ras(ras_n),.cas(cas_n),.we(we_n),.ba(ba),.addr(addr),.dm({dm3,dm2,dm1,dm0}),.dq(dq));
endmodule
