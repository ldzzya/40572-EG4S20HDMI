`timescale 1ns/1ps
module tb_resume_race;
reg clk=0,rst=1,locked=0,swap=0;always #20 clk=~clk;
sd_card_bmp dut(.clk(clk),.rst(rst),.spi_clk(clk),.spi_rst(rst),.key_next(1'b1),.key_auto(1'b1),.priority_mode(locked),.image_swap(swap),.playback_enable(1'b1),.active_frame_valid(1'b1),.active_frame_buf(2'd1),.active_width(16'd640),.active_height(16'd480),.commit_ack(1'b0),.write_finish_toggle(1'b0));
wav_file_player music(.clk(clk),.rst(rst),.start(swap),.checkpoint(locked),.resume_saved(1'b0),.pause_playback(locked),.start_cluster(32'd3),.start_size(32'd1024),.sector_valid(1'b0),.sector_done(1'b0),.sector_data(8'd0));
initial begin
force dut.ready=0;force dut.sd_init_done=0;
repeat(5)@(negedge clk);rst=0;
force dut.current_index=0;force dut.load_index=1;
force music.enabled=1;force music.phase=3;force music.pending=0;locked=1;swap=1;@(negedge clk);
if(music.saved_valid!==0)$fatal(1,"saved previous audio when new image/audio just started");
if(dut.saved_index!==1 || dut.saved_buf!==1 || !dut.saved_display)$fatal(1,"checkpoint raced with frame swap");
$display("PASS emergency checkpoint exactly on image swap saves the newly visible picture and buffer");$finish;
end
endmodule
