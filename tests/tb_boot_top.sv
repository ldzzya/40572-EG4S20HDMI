`timescale 1ns/1ps
// Actual delivered top, menu, presenter, timing, SDRAM read/write controllers.
// Force only peripheral boundaries (PLL/reset, media decode, FIFO data/counts).
// The HDMI encoder and physical SD/SDRAM chips are outside this regression.
// Shorten only the test raster's vertical active region for control checks;
// the separate timing_720 test verifies the unmodified 720-line frame timing.
module tb_boot_top;
reg clk=0;always #6.734 clk=~clk;
reg restore_cut=0;reg rst=1,key3=1,token=0;reg [3:0] sw=0;reg [1:0] bufidx=0;
top dut(.clk(clk),.rst_n(1'b1),.uart_rx(1'b1),.key1(1'b1),.key2(1'b1),.key3(key3),.sw(sw),.sd_miso(1'b1));
defparam dut.controls.DEBOUNCE_CYCLES=2,dut.controls.HOLD_CYCLES=30,dut.controls.REPEAT_CYCLES=12,dut.controls.SHORT_CYCLES=4;
defparam dut.priority_input.DEBOUNCE_CYCLES=3;
defparam dut.video_timing_data_m0.color_bar_m0.V_ACTIVE=32;
integer reads=0;
always @(posedge clk) if(!rst && dut.App_rd_en) reads=reads+1;
task frame; begin @(posedge dut.frame_tick);repeat(40) @(negedge clk);$display("frame %t active=%d page=%d",$time,dut.active_buf,dut.ui_page);$fflush();end endtask
task pixel;begin @(posedge dut.de);repeat(5) @(negedge clk);if(dut.vout_data!==24'h638ac7) $fatal(1,"active image pixel blocked: %h",dut.vout_data);end endtask
task press;begin key3=0;repeat(8) @(negedge clk);key3=1;repeat(12) @(negedge clk);end endtask
task home;begin key3=0;repeat(85) @(negedge clk);key3=1;repeat(12) @(negedge clk);end endtask
task check_buffer(input [1:0] idx);begin
 if(dut.frame_read_write_m0.frame_fifo_read_m0.read_addr_index_d1!==idx) $fatal(1,"wrong frame read index");
 if(dut.App_rd_addr < idx*691200 || dut.App_rd_addr >= (idx+1)*691200) $fatal(1,"read address outside selected buffer: %d",dut.App_rd_addr);
end endtask
initial begin
 force dut.video_clk=clk;force dut.ext_mem_clk=clk;
 force dut.rst_video=rst;force dut.rst_mem=rst;force dut.rst_sd=rst;
 force dut.Sdr_init_done=1;force dut.Sdr_init_ref_vld=0;force dut.Sdr_busy=0;
 force dut.frame_read_write_m0.wrusedw=0;force dut.frame_read_write_m0.rdusedw=0;
 force dut.sd_card_write_req=0;force dut.sd_card_write_en=0;
 force dut.video_read_data=24'h638ac7;
 force dut.hold_normal_frame=0;force dut.display_valid=1;force dut.image_count=2;
 force dut.warning_ready=0;force dut.warning_format=0;
 force dut.restore_cut=restore_cut;force dut.commit_toggle=token;force dut.disp_buf_idx=bufidx;
 force dut.source_width=1280;force dut.source_height=720;
 repeat(10) @(negedge clk);rst=0;
 frame();frame();
 if(dut.media_playing!==1 || dut.ui_page!==1 || dut.display_active!==0) $fatal(1,"boot not direct playback");
 check_buffer(0);token=1;frame();frame();
 if(dut.display_active!==1 || dut.fade_gain!==32 || dut.commit_ack!==token || dut.presenter.pause_playback!==0) $fatal(1,"boot did not present image");
 check_buffer(0);pixel();
 home();frame();if(dut.media_playing!==1) $fatal(1,"home stopped media");check_buffer(0);
 sw=1;repeat(30) @(negedge clk);bufidx=2;token=0;frame();frame();
 if(dut.media_playing!==1 || dut.active_buf!==2 || dut.commit_ack!==0 || dut.fade_gain!==32) $fatal(1,"SW1 override failed");check_buffer(2);
 press();if(dut.playback_requested!==1 || dut.media_playing!==1) $fatal(1,"emergency key lock failed");
 sw=0;restore_cut=1;bufidx=0;token=1;repeat(30) @(negedge clk);frame();frame();
 if(dut.media_playing!==1 || dut.active_buf!==0 || dut.commit_ack!==1) $fatal(1,"restore during live menu failed");check_buffer(0);restore_cut=0;
 press();frame();if(dut.media_playing!==1 || dut.active_buf!==0) $fatal(1,"resume failed");check_buffer(0);
 if(reads<100000) $fatal(1,"read controller did not run");
 $display("PASS actual top: automatic boot play, normal buffer 0, emergency buffer 2, live home menu and emergency return, key lock and resume; reads=%0d",reads);$finish;
end
initial begin #260000000;$fatal(1,"top regression timeout");end
endmodule
