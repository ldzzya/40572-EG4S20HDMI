`timescale 1ns/100fs
// Use Anlogic's functional PLL model; buffer has no logic-level latency.
module EG_LOGIC_BUFG(input i,output o);assign o=i;endmodule
module tb_clocks_720;
 reg clk_drive=0;always #10 clk_drive=~clk_drive;reg rst_drive=1;
 wire clk=clk_drive,rst=rst_drive;
 wire sl,vl,spi,mem,shift,ref33,pixel,serial;
 sys_pll sys(.refclk(clk),.reset(rst),.extlock(sl),.clk0_out(spi),.clk1_out(mem),.clk2_out(shift),.clk3_out(ref33));
 video_pll video(.refclk(ref33),.reset(rst),.extlock(vl),.clk0_out(pixel),.clk1_out(serial));
 realtime t0,dt;integer n;
 initial begin
  #100;rst_drive=0;#100000;
  if(!sl || !vl)$fatal(1,"PLL did not lock");
  @(posedge pixel);t0=$realtime;repeat(100)@(posedge pixel);dt=($realtime-t0)/100;
  if(dt<13.46 || dt>13.48)$fatal(1,"pixel clock period %f",dt);
  @(posedge serial);t0=$realtime;repeat(100)@(posedge serial);dt=($realtime-t0)/100;
  if(dt<2.69 || dt>2.70)$fatal(1,"serial clock period %f",dt);
  @(posedge mem);t0=$realtime;repeat(100)@(posedge mem);dt=($realtime-t0)/100;
  if(dt<20.19 || dt>20.22)$fatal(1,"memory clock period %f",dt);
  @(posedge spi);t0=$realtime;repeat(100)@(posedge spi);dt=($realtime-t0)/100;
  if(dt<10.09 || dt>10.12)$fatal(1,"SPI service clock period %f",dt);
  $display("PASS vendor PLL model: 74.25 MHz pixel, 371.25 MHz serializer, 49.5 MHz SDRAM, 99 MHz SD service");$finish;
 end
 initial begin #1000000;$fatal(1,"clock test timeout");end
endmodule
