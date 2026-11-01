`timescale 1ns/1ps
// The scheduler, BMP decoder, SD command/sector state machines, write-address
// generator and presenter are real RTL. Only the SPI byte transport/card and
// dual-clock FIFO storage are behavioral models (no encrypted SDRAM/HDMI IP).
module tb_pipeline;
reg clk=0,mem_clk=0;always #20 clk=~clk;always #12.5 mem_clk=~mem_clk;
reg spi_clk=0;always #5 spi_clk=~spi_clk;
reg rst=1,key_next=1,key_auto=1;wire [3:0] status;
wire display_valid,commit,ack,wr_req,wr_ack,we,finish,fifo_clear;
wire [31:0] pixel,sector;wire [15:0] width,height;wire [1:0] wb,db,active_buf;
wire [2:0] count;wire auto_en,active;wire [5:0] gain;
reg finish_toggle=0;reg tick=0;
integer tc=0,wp=0,rp=0,frames=0,pixel_count=0;reg [31:0] queue[0:511];
wire [9:0] used=wp-rp;
wire mem_we;wire [20:0] mem_addr;
reg [9:0] used0=0,used1=0;
wire ncs,sclk,mosi;
sd_card_bmp #(.CLK_FREQ_HZ(25000000),.SCAN_MAX_SECTOR(3603),.SCAN_TARGET_COUNT(4)) dut(
 .clk(clk),.rst(rst),.spi_clk(spi_clk),.spi_rst(rst),.key_next(key_next),.key_auto(key_auto),.state_code(status),
 .bmp_width(16'd640),.bmp_height(16'd480),.display_valid(display_valid),
 .commit_toggle(commit),.commit_ack(ack),.source_width(width),.source_height(height),
 .write_ready(used<440 && !fifo_clear),.write_finish_toggle(finish_toggle),
 .write_buf_idx(wb),.disp_buf_idx(db),.write_req(wr_req),.write_req_ack(wr_ack),
 .write_en(we),.write_data(pixel),.SD_nCS(ncs),.SD_DCLK(sclk),.SD_MOSI(mosi),.SD_MISO(1'b1),
 .debug_sector(sector),.image_count(count),.auto_play_en(auto_en));
frame_fifo_write #(.BURST_BITS(9),.BURST_SIZE(256)) writer(
 .rst(rst),.mem_clk(mem_clk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .App_rd_busy(tc%97<30),.App_wr_en(mem_we),.App_wr_addr(mem_addr),
 .write_req(wr_req),.write_req_ack(wr_ack),.write_finish(finish),
 .write_addr_0(21'd0),.write_addr_1(21'd307200),.write_addr_2(21'd0),.write_addr_3(21'd0),
 .write_addr_index(wb),.write_len(21'd307200),.fifo_aclr(fifo_clear),.rdusedw(used1));
frame_presenter presenter(.clk(clk),.rst(rst),.frame_tick(tick),.request_toggle(commit),
 .requested_buf(db),.source_width(width),.source_height(height),.ack_toggle(ack),
 .active_buf(active_buf),.display_active(active),.gain(gain),.shown_width(),.shown_height());
integer expected_addr,z;reg [23:0] expected;
always @(posedge clk) begin
 tc<=tc+1;tick<=tc%257==0;
 if(tc%1000000==0) begin $display("PROGRESS clocks=%0d state=%0d reader=%0d sector=%0d pixels=%0d frames=%0d",tc,dut.state,dut.bmp_read_m0.state,sector,pixel_count,frames);$fflush();end
 if(fifo_clear || rst) wp=0;
 else if(we) begin
  if(used>=512) $fatal(1,"FIFO overflow");
  queue[wp%512]=pixel;wp=wp+1;
 end
end
always @(posedge mem_clk) begin
 used0<=used;used1<=used0;
 if(rst || fifo_clear) begin rp=0;pixel_count=0;end
 else if(mem_we) begin
  if(used==0) $fatal(1,"FIFO underflow");
  expected_addr=wb*307200+(479-pixel_count/640)*640+pixel_count%640;
  if(mem_addr!==expected_addr) $fatal(1,"write address got %d expected %d",mem_addr,expected_addr);
  if(active && wb==active_buf) $fatal(1,"overwriting displayed frame");
  z=54+pixel_count*3;
  expected={dut.sd_card_top_m0.spi_master_m0.picture[z+2],
            dut.sd_card_top_m0.spi_master_m0.picture[z+1],
            dut.sd_card_top_m0.spi_master_m0.picture[z]};
  if(queue[rp%512][31:8]!==expected) $fatal(1,"source fixture pixel %d differs",pixel_count);
  rp=rp+1;pixel_count=pixel_count+1;
 end
 if(!rst && finish) begin
  if(pixel_count!=307200) $fatal(1,"incomplete frame committed: %d",pixel_count);
  finish_toggle<=~finish_toggle;frames=frames+1;
 end
end
initial begin
 repeat(8) @(negedge clk);rst=0;
 wait(display_valid);
 if(count!=1) $fatal(1,"first display waited for later images: count=%d",count);
 wait(count==2 && dut.state==6);
 key_next=0;repeat(500100) @(negedge clk);key_next=1;
 wait(frames==2);wait(active_buf==1 && gain==32 && ack==commit);
 repeat(8) @(negedge clk);
 if(status==14 || count!=2) $fatal(1,"bad final state %h count %d",status,count);
 $display("PASS integrated pipeline: supplied BMP pixels, SD commands, delayed init, first-image display, background scan, FIFO backpressure, 614400 flipped SDRAM writes, protected buffers and fast frame-boundary transition");
 $finish;
end
initial begin #3000000000;$fatal(1,"pipeline watchdog status=%h state=%d pixel=%d sector=%d",status,dut.state,pixel_count,sector);end
endmodule

module spi_master(input sys_clk,rst,input CPOL,CPHA,nCS_ctrl,input [15:0] clk_div,
 input wr_req,input [7:0] data_in,input MISO,output nCS,DCLK,MOSI,
 output wr_ack,output reg [7:0] data_out);
assign nCS=nCS_ctrl;assign DCLK=0;assign MOSI=0;
reg [3:0] phase=0;reg [7:0] tx;
assign wr_ack=phase==7;
reg [7:0] picture[0:921653];reg [2047:0] fixture;integer fd,n;
integer mode=0,pos=0,cmdnum=0,delay_bytes=0,extra=0,offset=0;
reg [31:0] arg=0;
initial begin
 if(!$value$plusargs("FILE=%s",fixture)) $fatal(1,"FILE fixture required");
 fd=$fopen(fixture,"rb");if(fd==0) $fatal(1,"fixture open failed");
 n=$fread(picture,fd);$fclose(fd);if(n!=921654) $fatal(1,"fixture size %d",n);
end
task exchange;
 input [7:0] value;integer location;
 begin
 data_out=8'hff;
 if(nCS_ctrl) begin mode=0;pos=0;end
 else case(mode)
  0:if(value[7:6]==2'b01) begin cmdnum=value&63;arg=0;pos=1;mode=1;end
  1:begin
   if(pos<=4) arg=(arg<<8)|value;
   if(pos==5) begin mode=2;delay_bytes=cmdnum==16 ? 64 : 2;end
   else pos=pos+1;
  end
  2:if(delay_bytes!=0) delay_bytes=delay_bytes-1;
    else begin
     data_out=(cmdnum==0 || cmdnum==8 || cmdnum==55) ? 8'h01 : 8'h00;
     if(cmdnum==8) begin mode=3;extra=4;end
     else if(cmdnum==17) begin mode=4;offset=0;end
     else mode=0;
    end
  3:begin data_out=extra==1 ? 8'haa : 0;extra=extra-1;if(extra==0) mode=0;end
  4:begin data_out=8'hfe;mode=5;offset=0;end
  5:begin
   location=(arg>=1801 ? arg-1801 : arg)*512+offset;
   if(offset<512 && arg<3602 && location<921654) data_out=picture[location];
   else data_out=0;
   offset=offset+1;if(offset==514) mode=0;
  end
 endcase
 end
endtask
always @(posedge sys_clk) begin
 if(rst) begin phase<=0;data_out<=8'hff;mode=0;pos=0;end
 else if(phase==0) begin if(wr_req) begin tx<=data_in;phase<=1;end end
 else begin
  if(phase==5) exchange(tx);
  if(phase==9) phase<=0;else phase<=phase+1'b1;
 end
end
endmodule

