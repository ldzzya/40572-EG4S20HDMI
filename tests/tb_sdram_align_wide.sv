`timescale 1ns/1ps
module alignment_case #(parameter WS=0,RS=0,CORRUPT=0)(output reg done=0);
 reg clk=0;always #10 clk=~clk;reg rst=1,init=0;
 reg we=0,re=0,fill=0;reg [20:0] wa=0,ra=0;reg [7:0] fill_index=0;wire [31:0] wd;
 wire ready,mwe,mre,valid,pending;wire [20:0] mwa,mra;wire [31:0] mwd,data;wire [3:0] mask,status;wire [7:0] detail;
 reg [31:0] memory[0:511],wdata[0:3];reg [3:0] we_pipe=0;reg [20:0] wa_pipe[0:3];
 reg [7:0] re_pipe=0;reg [20:0] ra_pipe[0:7];reg raw_valid=0;
 reg [31:0] raw_data=0;reg [4:0] busy_tail=0;wire busy=busy_tail!=0;
 integer i,b,k,received=0;reg checking=0;
 function [31:0] client_word(input integer n);client_word=32'h2948a175^(n*32'h01020307);endfunction
 wfifo_32_32_512 client_fifo(.clkr(clk),.clkw(clk),.rst(rst),
  .we(fill),.di(client_word(fill_index)),.re(we),.dout(wd),
  .empty_flag(),.full_flag(),.wrusedw(),.rdusedw());
 sdram_stream_align #(.PROBE_BASE(256),.TIMEOUT_CYCLES(1200)) dut(
  .clk(clk),.rst(rst),.init_done(init),.refresh_busy(1'b0),.controller_busy(busy),
  .write_en(we),.write_addr(wa),.write_data(wd),.write_mask(4'd0),.read_en(re),.read_addr(ra),
  .ready(ready),.status(status),.detail(detail),.pipeline_busy(pending),.memory_write_en(mwe),.memory_write_addr(mwa),
  .memory_write_data(mwd),.memory_write_mask(mask),.memory_read_en(mre),.memory_read_addr(mra),
  .memory_read_valid(CORRUPT==2 ? 1'b0 : raw_valid),.memory_read_data(raw_data),.read_valid(valid),.read_data(data));
 always @(posedge clk)begin
  if(rst)begin we_pipe<=0;re_pipe<=0;raw_valid<=0;busy_tail<=0;end
  else begin
   we_pipe<={we_pipe[2:0],mwe};wa_pipe[0]<=mwa;wdata[0]<=mwd;
   for(k=1;k<4;k=k+1)begin wa_pipe[k]<=wa_pipe[k-1];wdata[k]<=wdata[k-1];end
   if(we_pipe[1])memory[wa_pipe[1]]<=WS==2 ? mwd : wdata[WS==2 ? 0 : 1-WS];
   re_pipe<={re_pipe[6:0],mre};ra_pipe[0]<=mra;
   for(k=1;k<8;k=k+1)ra_pipe[k]<=ra_pipe[k-1];
   raw_valid<=re_pipe[3+RS];
   if(re_pipe[3])raw_data<=CORRUPT==3 ? 32'bx : memory[ra_pipe[3]]^(CORRUPT==1 ? 32'd1 : 32'd0);
   if(mwe || mre)busy_tail<=12;else if(busy_tail!=0)busy_tail<=busy_tail-1'b1;
   if(!ready && mwe && (mwa<256 || mwa>=384))$fatal(1,"probe touched image memory");
   if(checking && valid)begin
    if(data!==client_word(received))$fatal(1,"WS=%d RS=%d aligned playback mismatch %d: %h expected %h",WS,RS,received,data,client_word(received));
    received=received+1;
   end
  end
 end
 initial begin
  for(i=0;i<512;i=i+1)memory[i]=32'hfeedcafe;
  repeat(5)@(negedge clk);rst=0;repeat(5)@(negedge clk);init=1;
  wait(ready);@(negedge clk);
  if(status!==(CORRUPT==2 ? 4'he : CORRUPT ? 4'hf : 0))$fatal(1,"wrong calibration WS=%d RS=%d corruption=%d status=%h detail=%h",WS,RS,CORRUPT,status,detail);
  if(!CORRUPT && detail!==((WS+2)*16+RS+2))$fatal(1,"wrong taps WS=%d RS=%d got=%h",WS,RS,detail);
  for(i=0;i<256;i=i+1)if(memory[i]!==32'hfeedcafe)$fatal(1,"image region changed");
  for(i=384;i<512;i=i+1)if(memory[i]!==32'hfeedcafe)$fatal(1,"probe exceeded reserved words");
  if(busy || pending)$fatal(1,"calibration released while controller busy");
  if(!CORRUPT)begin
   for(i=0;i<128;i=i+1)begin fill=1;fill_index=i;@(negedge clk);end
   fill=0;repeat(12)@(negedge clk);
   for(b=0;b<2;b=b+1)begin
    wait(!busy && !pending);@(negedge clk);
    for(i=0;i<64;i=i+1)begin we=1;wa=b*64+i;@(negedge clk);end
    we=0;repeat(20)@(negedge clk);
   end
   for(i=0;i<128;i=i+1)if(memory[i]!==client_word(i))$fatal(1,"write alignment wrong at %d",i);
   checking=1;
   for(i=0;i<128;i=i+1)begin re=1;ra=i;@(negedge clk);end
   re=0;repeat(30)@(negedge clk);
   if(received!=128)$fatal(1,"read response count %d",received);
  end
  $display("PASS wide alignment: WS=%d RS=%d corruption=%d status=%h detail=%h; reserved probe, inverted second pattern and live traffic",WS,RS,CORRUPT,status,detail);
  done=1;
 end
endmodule
module tb_sdram_align_wide;
 wire [27:0] done;
 genvar w,r;
 generate for(w=0;w<5;w=w+1)begin:wg
  for(r=0;r<5;r=r+1)begin:rg
   alignment_case #(.WS(w-2),.RS(r-2)) c(done[w*5+r]);
  end
 end endgenerate
 alignment_case #(.CORRUPT(1)) corrupt(done[25]);
 alignment_case #(.CORRUPT(2)) timeout_test(done[26]);
 alignment_case #(.CORRUPT(3)) unknown_test(done[27]);
 initial begin wait(&done);$display("PASS wide calibration: 25 timing profiles, mismatches, unknown bus and timeout, safe fallback");$finish;end
 initial begin #3000000;$fatal(1,"alignment timeout");end
endmodule
