`timescale 1ns/1ps
// Actual FIFO RTL and RGB adapters; SDRAM uses an ideal application model.
// Optional full-frame throughput check only. Use run_modelsim_checks.py
// controller for the physical command/data-bus handshake regression.
module tb_memory_720;
 reg clk=0,memclk=0;always #6.734 clk=~clk;always #10.101 memclk=~memclk;
 reg rst=1,rr=0,pr=0,wr=0,we=0;reg [23:0] pd=0;
 wire rack,wack,wfinish,ready,are,awe,rv;wire [20:0] ra,wa;wire [31:0] wd,rd;wire [23:0] pixel;
 reg [31:0] memory[0:2073599];
 reg [20:0] request_queue[0:4095];integer qw=0,qr=0,cycle=0,read_index=0,writes=0;
 reg [31:0] result;reg result_valid=0;reg delayed_we=0;reg [20:0] delayed_wa;
 assign rd=result;assign rv=result_valid;
 frame_read_write #(.READ_DATA_BITS(24),.WRITE_DATA_BITS(24),.FRAME_WIDTH(960),.FRAME_HEIGHT(720)) dut(
 .rst(rst),.mem_clk(memclk),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
 .App_rd_en(are),.App_rd_addr(ra),.Sdr_rd_en(rv),.Sdr_rd_dout(rd),
 .read_clk(clk),.read_req(rr),.read_req_ack(rack),.read_finish(),
 .read_addr_0(21'd0),.read_addr_1(21'd691200),.read_addr_2(21'd1382400),.read_addr_3(21'd0),
 .read_addr_index(2'd0),.read_len(21'd691200),.read_en(pr),.read_data(pixel),
 .App_wr_en(awe),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(),
 .write_clk(clk),.write_req(wr),.write_req_ack(wack),.write_finish(wfinish),
 .write_addr_0(21'd0),.write_addr_1(21'd691200),.write_addr_2(21'd1382400),.write_addr_3(21'd0),
 .write_addr_index(2'd1),.write_len(21'd92160),.write_en(we),.write_ready(ready),.write_data(pd));
 function [23:0] pattern(input integer p);pattern=((p*65537)^(p>>5)^24'hbc9876)&24'hffffff;endfunction
 function [31:0] word_value(input integer w);
  reg [95:0] group;integer p;begin p=(w/3)*4;group={pattern(p+3),pattern(p+2),pattern(p+1),pattern(p)};
  case(w%3)0:word_value=group[31:0];1:word_value=group[63:32];2:word_value=group[95:64];endcase end
 endfunction
 integer expected_address;
 always @(posedge memclk)begin
  cycle<=cycle+1;result_valid<=0;
  if(rst)begin qw=0;qr=0;delayed_we<=0;end
  else begin
   if(are)begin request_queue[qw%4096]=ra;qw=qw+1;end
   // Periodically withhold responses for refresh; drain in order afterward.
   if(qr<qw && cycle%773>=7 && cycle%270>=8)begin
    result<=memory[request_queue[qr%4096]];result_valid<=1;qr=qr+1;
   end
   if(qw-qr>200)$fatal(1,"memory requests exceed service bandwidth");
   delayed_we<=awe;delayed_wa<=wa;
   if(delayed_we)begin
    expected_address=691200+(719-writes/960)*960+writes%960;
    if(delayed_wa!==expected_address || wd!==word_value(writes))$fatal(1,"packed write flip mismatch %d at %d value %h",writes,delayed_wa,wd);
    memory[delayed_wa]<=wd;writes=writes+1;
   end
   if(awe && are)$fatal(1,"simultaneous SDRAM read/write commands");
  end
 end
 integer x,y,f,i,j;
 initial begin
  for(i=0;i<691200;i=i+1)memory[i]=word_value(i);
  repeat(12)@(negedge clk);rst=0;
  fork
   begin
    for(f=0;f<3;f=f+1)begin
     rr=1;wait(rack);@(negedge clk);rr=0;repeat(1000)@(negedge clk);
     read_index=0;
     for(y=0;y<720;y=y+1)begin
      for(x=0;x<1280;x=x+1)begin
       pr=1;@(posedge clk);#1;
       if(pixel!==pattern(read_index))$fatal(1,"memory read mismatch frame=%d pixel=%d %h expected %h used=%d",f,read_index,pixel,pattern(read_index),dut.wrusedw);
       read_index=read_index+1;@(negedge clk);
      end
      pr=0;repeat(370)@(negedge clk);
     end
     repeat(48000)@(negedge clk);
     if(dut.unpacker.underflow)$fatal(1,"framebuffer underflow");
    end
   end
   begin
    repeat(1500)@(negedge clk);wr=1;wait(wack);@(negedge clk);wr=0;wait(!wack);
    // An aggressive concurrent image load, faster than the actual SPI card.
    for(j=0;j<122880;j=j+1)begin
     @(negedge clk);while(!ready)@(negedge clk);we=1;pd=pattern(j);
     @(negedge clk);we=0;repeat(2)@(negedge clk);
    end
    wait(wfinish);if(writes!=92160)$fatal(1,"incomplete packed write %d",writes);
   end
  join
  $display("PASS memory720: 49.5MHz SDRAM / 74.25MHz pixels, full RGB24 frames, concurrent writes, refresh/latency gaps, bank protection and vertical flip");$finish;
 end
 initial begin #1000000000;$fatal(1,"memory test timeout writes=%d read=%d",writes,read_index);end
endmodule

