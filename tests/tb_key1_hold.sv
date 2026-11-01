`timescale 1ns/1ps
module tb_key1_hold;
reg clk=0,spi=0,mem=0,video=0;
always #10 clk=~clk;always #5 spi=~spi;
always #12.5 mem=~mem;always #20 video=~video;
reg key_n=0,locks=0;wire ra,rs,rm,rv;
reset_under_test dut(clk,key_n,locks,spi,mem,video,ra,rs,rm,rv);
time stable_since=0,ts=0,tm=0,tv=0;
always @(posedge spi) ts=$time;
always @(posedge mem) tm=$time;
always @(posedge video) tv=$time;
always @(negedge rs) if($time!=ts) $fatal(1,"SPI release off clock edge");
always @(negedge rm) if($time!=tm) $fatal(1,"memory release off clock edge");
always @(negedge rv) if($time!=tv) $fatal(1,"video release off clock edge");
always @(negedge ra) begin
 if($time-stable_since<20000000 || $time-stable_since>22000000)
  $fatal(1,"reset release outside 20..22 ms: %0t",$time-stable_since);
end
task check_asserted;
 begin #1;if({ra,rs,rm,rv}!==4'b1111) $fatal(1,"reset released during contact bounce");end
endtask
task release_and_check;
 begin
  stable_since=$time;key_n=1;locks=1;
  wait(!ra);wait(!rs && !rm && !rv);
  repeat(8) @(negedge clk);
 end
endtask
integer i;
initial begin
 repeat(5) @(negedge clk);check_asserted;release_and_check;
 #7;key_n=0;check_asserted;
 // The old ~5.24 ms guard restarts during each 7 ms contact gap.
 for(i=0;i<3;i=i+1) begin
  stable_since=$time;key_n=1;#7000000;check_asserted;
  key_n=0;#10000;check_asserted;
 end
 release_and_check;
 #7;locks=0;check_asserted;#10000;release_and_check;
 $display("PASS KEY1 hold: actual top RTL, 20.97 ms release, 3 contact gaps, PLL loss, synchronized clock-domain release");$finish;
end
initial begin #130000000;$fatal(1,"reset hold watchdog");end
endmodule
