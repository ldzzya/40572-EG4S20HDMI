`timescale 1ns/1ps
// Actual delivered top, menu, presenter, timing, SDRAM read/write controllers.
// Force only peripheral boundaries (PLL/reset, media decode, FIFO data/counts).
// The HDMI encoder and physical SD/SDRAM chips are outside this regression.
module tb_home_top;
reg clk=0;always #20 clk=~clk;
reg rst=1,key3=1,token=0;reg [3:0] sw=0;reg [1:0] bufidx=0;
top dut(.clk(clk),.rst_n(1'b1),.uart_rx(1'b1),.key1(1'b1),.key2(1'b1),.key3(key3),.sw(sw),.sd_miso(1'b1));
defparam dut.controls.DEBOUNCE_CYCLES=2,dut.controls.HOLD_CYCLES=30,dut.controls.REPEAT_CYCLES=12,dut.controls.SHORT_CYCLES=4;
defparam dut.priority_input.DEBOUNCE_CYCLES=3;
integer reads=0;
always @(posedge clk) if(!rst && dut.App_rd_en) reads=reads+1;
task frame; begin @(posedge dut.frame_tick);repeat(40) @(negedge clk);end endtask
task pixel;begin @(posedge dut.de);repeat(5) @(negedge clk);if(dut.vout_data!==24'h638ac7) $fatal(1,"active image pixel blocked: %h",dut.vout_data);end endtask
task press;begin key3=0;repeat(8) @(negedge clk);key3=1;repeat(12) @(negedge clk);end endtask
task home;begin key3=0;repeat(85) @(negedge clk);key3=1;repeat(12) @(negedge clk);end endtask
task check_buffer(input [1:0] idx);begin
 if(dut.frame_read_write_m0.frame_fifo_read_m0.read_addr_index_d1!==idx) $fatal(1,"wrong frame read index");
 if(dut.App_rd_addr < idx*307200 || dut.App_rd_addr >= (idx+1)*307200) $fatal(1,"read address outside selected buffer: %d",dut.App_rd_addr);
end endtask
initial begin
 force dut.video_clk=clk;force dut.ext_mem_clk=clk;
 force dut.rst_video=rst;force dut.rst_mem=rst;force dut.rst_sd=rst;
 force dut.Sdr_init_done=1;force dut.Sdr_init_ref_vld=0;force dut.Sdr_busy=0;
 force dut.frame_read_write_m0.wrusedw=0;force dut.frame_read_write_m0.rdusedw=0;
 force dut.sd_card_write_req=0;force dut.sd_card_write_en=0;
 force dut.video_read_data=32'h638ac700;
 force dut.background_ready=1;force dut.commit_toggle=token;force dut.disp_buf_idx=bufidx;
 force dut.source_width=640;force dut.source_height=480;
 repeat(10) @(negedge clk);rst=0;
 frame();frame();
 if(dut.media_playing!==0 || dut.home_frame!==1 || dut.display_active!==0) $fatal(1,"boot not paused");
 if(dut.shown_ready!==1) $fatal(1,"home background blocked before first gallery image");
 check_buffer(2);pixel();
 press();if(dut.media_playing!==1) $fatal(1,"KEY3 playback signal disconnected");
 token=1;frame();frame();
 if(dut.home_frame!==0 || dut.display_active!==1 || dut.fade_gain!==32 || dut.commit_ack!==token || dut.presenter.pause_playback!==0) $fatal(1,"start did not present image");
 check_buffer(0);
 pixel();
 home();frame();if(dut.media_playing!==0 || dut.home_frame!==1) $fatal(1,"return home failed");check_buffer(2);
 bufidx=1;token=0;frame();if(dut.commit_ack!==1) $fatal(1,"paused presenter advanced");
 sw=1;repeat(30) @(negedge clk);frame();frame();
 if(dut.media_playing!==1 || dut.home_frame!==0 || dut.active_buf!==1 || dut.commit_ack!==0 || dut.fade_gain!==32) $fatal(1,"SW1 override failed");check_buffer(1);
 press();if(dut.playback_requested!==0 || dut.media_playing!==1) $fatal(1,"emergency key lock failed");
 sw=0;repeat(30) @(negedge clk);frame();
 if(dut.media_playing!==0 || dut.home_frame!==1) $fatal(1,"emergency exit not home");check_buffer(2);
 press();frame();if(dut.media_playing!==1 || dut.home_frame!==0 || dut.active_buf!==1) $fatal(1,"resume failed");check_buffer(1);
 if(reads<100000) $fatal(1,"read controller did not run");
 $display("PASS actual top: home pixels before first image, KEY3 start, SDRAM buffers 2/0/1, pause pending commit, SW1 override/key lock, return and resume; reads=%0d",reads);$finish;
end
initial begin #260000000;$fatal(1,"top regression timeout");end
endmodule
