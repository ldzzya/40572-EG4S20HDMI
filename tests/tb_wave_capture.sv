module tb_wave_capture;
reg clk=0,rst=1,tick=0,av=0;reg[23:0] pcm=0;always #5 clk=~clk;
video_effects dut(.clk(clk),.rst(rst),.frame_tick(tick),.vs(1'b1),.de(1'b0),.rgb(24'd0),
 .gain(6'd32),.switches(4'd0),.volume_level(5'd20),.subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.subtitle_addr(),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
 .image_ready(1'b1),.scan_sector(32'd0),.image_count(3'd1),.autoplay(1'b0),
 .status(4'd1),.audio_status(4'd3),.audio_valid(av),.audio_left(pcm),.audio_right(pcm));
integer i;reg bank;
task frame;
 begin tick=1;@(negedge clk);tick=0;end
endtask
initial begin
 repeat(5) @(negedge clk);rst=0;bank=dut.rd_bank;
 av=1;pcm=-24'sd100000;@(negedge clk);pcm=0;
 for(i=0;i<256;i=i+1) @(negedge clk);
 if(!dut.wave_pending || dut.wave_valid || dut.rd_bank!=bank) $fatal(1,"capture did not wait for display boundary");
 pcm=24'sd2000000;repeat(50) @(negedge clk);
 if(dut.rd_bank!=bank) $fatal(1,"display bank changed within a frame");
 av=0;frame();
 if(!dut.wave_valid || dut.rd_bank==bank) $fatal(1,"captured wave not published");
 for(i=0;i<256;i=i+1) if(dut.wave_ram[{dut.rd_bank,8'(i)}]!==14'd5160) $fatal(1,"published silence buffer overwritten");
 bank=dut.rd_bank;pcm=0;av=1;repeat(1300) @(negedge clk);av=0;
 if(!dut.wave_pending) $fatal(1,"no fallback trigger for silence");
 frame();
 if(dut.rd_bank==bank) $fatal(1,"silence snapshot not swapped");
 for(i=0;i<256;i=i+1) if(dut.wave_ram[{dut.rd_bank,8'(i)}]!==14'd5160) $fatal(1,"silence baseline not centered");
 $display("PASS waveform: rising-zero trigger, immutable displayed bank, vblank swap and DC/silence fallback");$finish;
end
endmodule
