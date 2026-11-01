`timescale 1ns/1ps
module tb_subtitle;
reg clk=0,rst=1,rx=1,tick=0;always #20 clk=~clk;
reg [6:0] addr=0;wire[7:0] ch;wire active,changed,tx;wire[3:0] count;
subtitle_uart dut(clk,rst,rx,tick,addr,ch,active,changed,tx,count);
wire[7:0] ack;wire ack_valid,ack_err;
uart_rx_byte ack_receiver(clk,rst,tx,ack,ack_valid,ack_err);
integer ks=0,es=0,bs=0,i;
always @(negedge clk) if(ack_valid) begin
 case(ack) "K":ks=ks+1;"E":es=es+1;"B":bs=bs+1;default:$fatal(1,"unknown ack");endcase
end
task byte_send(input [7:0] b,input integer clocks,input good_stop);
 integer j;begin rx=0;repeat(clocks) @(negedge clk);
 for(j=0;j<8;j=j+1) begin rx=b[j];repeat(clocks) @(negedge clk);end
 rx=good_stop;repeat(clocks) @(negedge clk);rx=1;repeat(clocks) @(negedge clk);
 end
endtask
task send(input string s);integer j;begin for(j=0;j<s.len();j=j+1) byte_send(s[j],217,1);end endtask
task frame;begin tick=1;@(negedge clk);tick=0;repeat(2400) @(negedge clk);end endtask
task expect_text(input string s);integer j;begin
 for(j=0;j<80;j=j+1) begin addr=j;#1;
  if(ch!==(j<s.len()?s[j]:8'd32)) $fatal(1,"subtitle char %0d got %h",j,ch);
 end end endtask
initial begin
 repeat(8) @(negedge clk);rst=0;
 // Narrow glitch is not a UART start bit.
 rx=0;repeat(20) @(negedge clk);rx=1;repeat(2200) @(negedge clk);
 if(dut.prefix || dut.bad) $fatal(1,"false start accepted");
 send("TEXT Hello FPGA!");byte_send(13,217,1);byte_send(10,217,1);
 if(active || !dut.pending) $fatal(1,"partial line visible before frame");
 frame();expect_text("Hello FPGA!");if(!active || ks!=1) $fatal(1,"commit ACK missing");
 send("TEXT Second");expect_text("Hello FPGA!");send("\n");frame();expect_text("Second");
 send("TEXT ");for(i=0;i<81;i=i+1) send("a");send("\n");frame();expect_text("Second");
 if(es!=1) $fatal(1,"overlong line not rejected");
 send("BAD x\n");frame();expect_text("Second");if(es!=2) $fatal(1,"bad prefix");
 send("TEXT ");byte_send(8'hc3,217,1);send("\n");frame();expect_text("Second");
 send("TEXT pending\n");send("TEXT busy\n");frame();expect_text("pending");
 if(bs!=1) $fatal(1,"busy line not rejected");
 // Blank text clears the entire previous subtitle.
 send("TEXT \n");frame();expect_text("");
 // Slight baud mismatch and a damaged stop bit.
 byte_send("T",219,1);byte_send("E",219,1);byte_send("X",219,1);byte_send("T",219,1);
 byte_send(" ",219,1);byte_send("Z",219,1);byte_send(10,219,1);frame();expect_text("Z");
 send("TEXT ");byte_send("X",217,0);send("\n");frame();expect_text("Z");
 send("TEXT abandoned");force dut.timeout_count=24999999;@(negedge clk);release dut.timeout_count;
 repeat(2400) @(negedge clk);if(dut.prefix!=0) $fatal(1,"line timeout did not recover");
 send("TEXT Recovered\n");frame();expect_text("Recovered");
 // Commit and busy response on the same clock must both survive the TX queue.
 send("TEXT Queued\n");i=ks;
 fork
  send("\n");
  begin wait(dut.valid && dut.data==10);@(negedge clk);tick=1;@(negedge clk);tick=0;end
 join
 repeat(5000) @(negedge clk);expect_text("Queued");
 if(ks!=i+1 || bs!=2) $fatal(1,"simultaneous commit/busy acknowledgements lost");
 send("TEXT Bound");
 fork
  send("ary");
  begin wait(dut.valid && dut.data=="a");@(negedge clk);dut.timeout_count=24999999;
   @(negedge clk);end
 join
 send("\n");frame();expect_text("Boundary");
 if(ack_err) $fatal(1,"TX framing error");
 rst=1;@(negedge clk);if(active || !tx) $fatal(1,"UART reset");
 $display("PASS subtitle: serial 115200 RX/TX, glitch, CRLF, atomic frame commit, overflow/encoding/busy/stop/timeout rejection, baud tolerance and reset");$finish;
end
initial begin #100000000;$fatal(1,"UART timeout");end
endmodule
