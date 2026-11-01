// Isolate the dwell scheduler while its reader is busy finding more pictures.
module tb_autoplay;
reg clk=0,rst=1;always #5 clk=~clk;
sd_card_bmp #(.CLK_FREQ_HZ(1000)) dut(
 .clk(clk),.spi_clk(clk),.rst(rst),.spi_rst(rst),.key_next(1'b1),.key_auto(1'b1),
 .bmp_width(16'd640),.bmp_height(16'd480),.commit_ack(1'b0),
 .write_ready(1'b1),.write_finish_toggle(1'b0),.write_req_ack(1'b0),.SD_MISO(1'b1));
initial begin
 repeat(5) @(negedge clk);rst=0;
 force dut.display_valid=1;force dut.auto_play_en=1;force dut.image_count=2;
 force dut.state=2;
 dut.catalogue[1]=4096;
 repeat(5500) @(negedge clk);
 if(!dut.auto_due || dut.auto_count!=4999) $fatal(1,"background scan restarted autoplay dwell");
 release dut.state;dut.state=6;
 @(negedge clk);
 if(dut.state!=3 || dut.load_index!=1 || dut.load_sector!=4096) $fatal(1,"next image not loaded after background batch");
 force dut.state=2;force dut.image_count=1;
 repeat(5500) @(negedge clk);
 if(dut.auto_due) $fatal(1,"single image repeatedly reloads");
 force dut.image_count=2;force dut.auto_press=1;#1;
 if(dut.auto_due) $fatal(1,"disable button races an automatic switch");
 $display("PASS autoplay: dwell survives background scan, loads next image, holds single image, disable wins");$finish;
end
endmodule
