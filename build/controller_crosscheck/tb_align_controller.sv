`timescale 1ns/1ps
// Real FIFO schedulers and RGB adapters. The physical SDRAM and vendor FIFOs
// are modeled at their interfaces; this is a bandwidth/data-integrity test,
// not an electrical SDRAM or HDMI compliance test.
module tb_align_controller;
 reg clk=0,memclk=0;always #6.734 clk=~clk;always #10.101 memclk=~memclk;
 reg rst=1,rr=0,pr=0,wr=0,we=0;reg [23:0] pd=0;
 wire rack,wack,wfinish,ready,are,awe,rv;wire [20:0] ra,wa;wire [31:0] wd,rd;wire [23:0] pixel;

 reg sft=0,manual_ref=0;always @(memclk)sft<=#8.84 memclk;
 wire init,refv,busy,sc,ras,cas,wen;wire [10:0] addr;wire [1:0] ba;wire [3:0] dm;tri [31:0] dq;
 wire raw_init,raw_busy,raw_valid,mwe,mre,pending;wire [20:0] mwa,mra;wire [31:0] mwd,mrd;
 wire [3:0] mask,align_status;
 sdram_stream_align aligner(.clk(memclk),.rst(rst),.init_done(raw_init),.controller_busy(raw_busy),.refresh_busy(refv),
 .write_en(awe),.write_addr(wa),.write_data(wd),.write_mask(4'd0),.read_en(are),.read_addr(ra),
 .ready(init),.status(align_status),.pipeline_busy(pending),.memory_write_en(mwe),.memory_write_addr(mwa),.memory_write_data(mwd),.memory_write_mask(mask),
 .memory_read_en(mre),.memory_read_addr(mra),.memory_read_valid(raw_valid),.memory_read_data(mrd),.read_valid(rv),.read_data(rd));
 assign busy=raw_busy || pending || !init;
 sdr_as_ram ctrl(.Sdr_clk(memclk),.Sdr_clk_sft(sft),.Rst(rst),.App_ref_req(manual_ref),
 .App_wr_en(mwe),.App_wr_addr(mwa),.App_wr_din(mwd),.App_wr_dm(mask),.App_rd_en(mre),.App_rd_addr(mra),
 .Sdr_init_done(raw_init),.Sdr_init_ref_vld(refv),.Sdr_busy(raw_busy),.Sdr_rd_en(raw_valid),.Sdr_rd_dout(mrd),
 .SDRAM_CLK(sc),.SDR_RAS(ras),.SDR_CAS(cas),.SDR_WE(wen),.SDR_ADDR(addr),.SDR_BA(ba),.SDR_DM(dm),.SDR_DQ(dq));
 sdram_model mem(.clk(sc),.ras(ras),.cas(cas),.we(wen),.ba(ba),.addr(addr),.dm(dm),.dq(dq));

 reg [20:0] request_queue[0:4095];integer qw=0,qr=0,cycle=0,read_index=0,writes=0;
 reg [31:0] result;reg result_valid=0;reg delayed_we=0;reg [20:0] delayed_wa;

 frame_read_write #(.READ_DATA_BITS(24),.WRITE_DATA_BITS(24),.FRAME_WIDTH(960),.FRAME_HEIGHT(720)) dut(
 .rst(rst),.mem_clk(memclk),.Sdr_init_done(init),.Sdr_init_ref_vld(refv),.Sdr_busy(busy),
 .App_rd_en(are),.App_rd_addr(ra),.Sdr_rd_en(rv),.Sdr_rd_dout(rd),
 .read_clk(clk),.read_req(rr),.read_req_ack(rack),.read_finish(),
 .read_addr_0(21'd0),.read_addr_1(21'd691200),.read_addr_2(21'd1382400),.read_addr_3(21'd0),
 .read_addr_index(2'd0),.read_len(21'd691200),.read_en(pr),.read_data(pixel),
 .App_wr_en(awe),.App_wr_addr(wa),.App_wr_din(wd),.App_wr_dm(),
 .write_clk(clk),.write_req(wr),.write_req_ack(wack),.write_finish(wfinish),
 .write_addr_0(21'd0),.write_addr_1(21'd691200),.write_addr_2(21'd1382400),.write_addr_3(21'd0),
 .write_addr_index(2'd1),.write_len(21'd3840),.write_en(we),.write_ready(ready),.write_data(pd));
 function [23:0] pattern(input integer p);pattern=((p*65537)^(p>>5)^24'hbc9876)&24'hffffff;endfunction
 function [31:0] word_value(input integer w);
  reg [95:0] group;integer p;begin p=(w/3)*4;group={pattern(p+3),pattern(p+2),pattern(p+1),pattern(p)};
  case(w%3)0:word_value=group[31:0];1:word_value=group[63:32];2:word_value=group[95:64];endcase end
 endfunction
 integer expected_address;
 initial begin
  wait(init);repeat(2000)@(negedge memclk);manual_ref=1;
  @(negedge memclk);manual_ref=0;
 end
 always @(posedge memclk)begin
  cycle<=cycle+1;result_valid<=0;
  if(rst)begin qw=0;qr=0;delayed_we<=0;end
  else begin
   delayed_we<=awe;delayed_wa<=wa;
   if(awe)begin
    expected_address=691200+(719-writes/960)*960+writes%960;
    if(wa!==expected_address || wd!==word_value(writes))$fatal(1,"packed write flip mismatch %d at %d value %h",writes,delayed_wa,wd);
    writes=writes+1;
   end
   if(awe && are)$fatal(1,"simultaneous SDRAM read/write commands");
  end
 end
 integer x,y,f,i,j;
 initial begin
  for(i=0;i<691200;i=i+1)mem.memory[i]=word_value(i);
  repeat(12)@(negedge clk);rst=0;
  repeat(10)@(negedge memclk);force ctrl.\u1_init_ref/pwr_200ms_cnt =18'h20000;
  repeat(2)@(negedge memclk);release ctrl.\u1_init_ref/pwr_200ms_cnt ;
  wait(init);if(align_status!==0)$fatal(1,"controller calibration expected 0 got %h",align_status);repeat(20)@(negedge clk);
  fork
   begin
    for(f=0;f<1;f=f+1)begin
     rr=1;wait(rack);@(negedge clk);rr=0;repeat(1000)@(negedge clk);
     read_index=0;
     for(y=0;y<16;y=y+1)begin
      for(x=0;x<1280;x=x+1)begin
       pr=1;@(posedge clk);#1;
       if(pixel!==pattern(read_index))$fatal(1,"memory read mismatch frame=%d pixel=%d %h expected %h used=%d",f,read_index,pixel,pattern(read_index),dut.wrusedw);
       read_index=read_index+1;@(negedge clk);
      end
      pr=0;repeat(370)@(negedge clk);
     end
     repeat(500)@(negedge clk);
     if(dut.unpacker.underflow)$fatal(1,"framebuffer underflow");
    end
   end
   begin
    repeat(1500)@(negedge clk);wr=1;wait(wack);@(negedge clk);wr=0;wait(!wack);
    // An aggressive concurrent image load, faster than the actual SPI card.
    for(j=0;j<5120;j=j+1)begin
     @(negedge clk);while(!ready)@(negedge clk);we=1;pd=pattern(j);
     @(negedge clk);we=0;repeat(2)@(negedge clk);
    end
    wait(wfinish);repeat(50)@(negedge memclk);
    for(i=0;i<3840;i=i+1)if(mem.memory[691200+(719-i/960)*960+i%960]!==word_value(i))$fatal(1,"physical framebuffer mismatch word=%d got=%h",i,mem.memory[691200+(719-i/960)*960+i%960]);
    if(writes!=3840)$fatal(1,"incomplete packed write %d",writes);
   end
  join
  if(mem.nrefresh==0)$fatal(1,"refresh not exercised");
  $display("PASS calibration + actual controller + FIFO: 16 native RGB24 lines, 3840 concurrent words, refresh=%d, vertical flip and optimized unpacker",mem.nrefresh);$finish;
 end
 initial begin #2000000;$fatal(1,"memory test timeout writes=%d read=%d",writes,read_index);end
endmodule


