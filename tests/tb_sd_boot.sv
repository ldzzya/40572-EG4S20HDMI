`timescale 1ns/1ps
// Real sector-controller initialization + real BMP reader. The card command
// responder deliberately delays CMD16, as a real SPI transfer does.
module tb_sd_boot;
reg clk=0; always #5 clk=~clk;
reg rst=1,start=0; wire init,read_req,dv,done,scan_done;
wire [31:0] addr; wire [7:0] data; wire [3:0] status; wire [2:0] count;
wire cmd_req,br; wire [47:0] cmd; wire [15:0] div;
reg cmd_ack=0,br_ack=0,br_valid=0;reg [7:0] br_data=0;
integer reads=0,delay_count=0,remaining=0,idx=0;reg command_busy=0;
sd_card_sec_read_write #(.SPI_HIGH_SPEED_DIV(2)) controller(
 .clk(clk),.rst(rst),.sd_init_done(init),.sd_sec_read(read_req),.sd_sec_read_addr(addr),
 .sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(done),
 .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
 .spi_clk_div(div),.cmd_req(cmd_req),.cmd_req_ack(cmd_ack),.cmd_req_error(1'b0),.cmd(cmd),
 .block_read_req(br),.block_read_valid(br_valid),.block_read_data(br_data),.block_read_req_ack(br_ack),
 .block_write_data_rd(1'b0),.block_write_req_ack(1'b0));
bmp_read #(.TIMEOUT_CYCLES(3000)) reader(
 .clk(clk),.rst(rst),.scan_start(start),.scan_start_sector(32'd0),.scan_max_sector(32'd0),
 .scan_target_count(3'd1),.scan_done(scan_done),.scan_found_total(count),
 .load_start(1'b0),.load_sector(32'd0),.sd_init_done(init),.state_code(status),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req_ack(1'b0),.write_ready(1'b1),
 .sd_sec_read(read_req),.sd_sec_read_addr(addr),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(dv),.sd_sec_read_end(done));
function [7:0] card;
 input integer a; begin
 card=0;
 case(a) 0:card="B";1:card="M";2:card=58;10:card=54;14:card=40;
 18:card=1;22:card=1;26:card=1;28:card=24;endcase
 end
endfunction
always @(negedge clk) begin
 cmd_ack=0;br_valid=0;br_ack=0;
 if(command_busy) begin
  if(delay_count==0) begin cmd_ack=1;command_busy=0;end
  else delay_count=delay_count-1;
 end else if(cmd_req) begin command_busy=1;delay_count=cmd[47:40]==16 ? 120 : 10;end
 if(remaining>0) begin
  br_data=card(idx);br_valid=1;idx=idx+1;remaining=remaining-1;
 end else if(idx==512) begin br_ack=1;idx=513;end
 else if(br && idx==0) begin remaining=512;reads=reads+1;end
end
initial begin
 repeat(5) @(negedge clk);rst=0;
 wait(init);@(negedge clk);start=1;@(negedge clk);start=0;
 wait(scan_done);repeat(4) @(negedge clk);
 if(count!=1 || reads!=1) $fatal(1,"BOOT REGRESSION: first read lost, reads=%0d count=%0d status=%0h",reads,count,status);
 if(div!=2) $fatal(1,"configured SPI divider overridden: %0d",div);
 $display("PASS SD boot: delayed CMD16, first sector retained, configured SPI divider");$finish;
end
initial begin #1000000;$fatal(1,"boot watchdog");end
endmodule
