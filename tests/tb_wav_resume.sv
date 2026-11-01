`timescale 1ns/1ps
module tb_wav_resume;
 reg clk=0;always #20 clk=~clk;
 reg pause=0,checkpoint=0,resume_saved=0;
 reg rst=1,start=0;reg [31:0] start_cluster=2,start_size;
 wire [31:0] file_cluster,file_size,sector_addr;wire sector_req;
 reg [7:0] sector_data;reg sector_valid=0,sector_done=0;
 wire valid;wire [23:0] left,right;wire [3:0] status;wire [10:0] buffered;
 wav_file_player dut(clk,rst,start,start_cluster,start_size,file_cluster,file_size,sector_req,sector_addr,
  sector_data,sector_valid,sector_done,valid,left,right,status,buffered,pause,checkpoint,resume_saved);
 reg [7:0] bytes[0:8191];integer addr=0,waits=0,bi=0;reg busy=0;
 always @(posedge clk) begin
  sector_valid<=0;sector_done<=0;
  if(rst) begin busy<=0;waits<=0;bi<=0;end
  else if(!busy && sector_req) begin busy<=1;addr<=sector_addr*512;waits<=5000;bi<=0;end
  else if(busy) begin
   if(waits!=0) waits<=waits-1;
   else if(bi<512) begin sector_data<=bytes[addr+bi];sector_valid<=1;bi<=bi+1;end
   else begin sector_done<=1;busy<=0;end
  end
 end
 task le32(input integer a,input integer v);begin bytes[a]=v;bytes[a+1]=v>>8;bytes[a+2]=v>>16;bytes[a+3]=v>>24;end endtask
 task le16(input integer a,input integer v);begin bytes[a]=v;bytes[a+1]=v>>8;end endtask
 integer nbits,nch,hz,sz,i,j,v,base,fmt_size,frames=301,checked=0,cycle=0,last_tick=0,ticks=0;
 integer source_index,phase,weight,expected_l,expected_r,next_l,next_r,actual_l,actual_r,mode;
 reg monitoring=0,heard=0;
 function integer sample(input integer n,input integer c);
  begin sample=(((n%301)*8192)-1234432);if(c!=0) sample=-sample+256;end
 endfunction
 task fixture;
  begin
   for(i=0;i<8192;i=i+1) bytes[i]=0;
   le32(0,32'h46464952);le32(8,32'h45564157);
   // Odd-sized metadata exercises pad handling; fmt is deliberately not byte 12.
   le32(12,32'h4b4e554a);le32(16,5);bytes[20]=8'he1;
   fmt_size=mode[3] ? 40 : 18;
   le32(26,32'h20746d66);le32(30,fmt_size);le16(34,mode[3] ? 65534 : 1);le16(36,nch);le32(38,hz);
   le32(42,hz*nch*nbits/8);le16(46,nch*nbits/8);le16(48,nbits);
   if(mode[3]) begin
    le16(50,22);le16(52,nbits);le32(54,nch==2 ? 3 : 4);
    le32(58,1);le32(62,32'h00100000);le32(66,32'haa000080);le32(70,32'h719b3800);
   end
   base=34+fmt_size;le32(base,32'h61746164);sz=frames*nch*nbits/8;le32(base+4,sz);base=base+8;
   for(i=0;i<frames;i=i+1) for(j=0;j<nch;j=j+1) begin
    v=sample(i,j);
    if(nbits==16) begin le16(base,v>>>8);base=base+2;end
    else begin bytes[base]=v;bytes[base+1]=v>>8;bytes[base+2]=v>>16;base=base+3;end
   end
   start_size=base;le32(4,base-8);
  end
 endtask
 always @(negedge clk) begin
  cycle=cycle+1;
  if(rst) begin last_tick=0;ticks=0;end
  else if(valid) begin
   if(last_tick!=0 && cycle-last_tick!=520 && cycle-last_tick!=521) $fatal(1,"not 48kHz gap=%0d",cycle-last_tick);
   last_tick=cycle;ticks=ticks+1;
   if(monitoring && (heard || left!=0 || right!=0)) begin
    heard=1;
    source_index=(hz==44100 ? checked*147/160 : checked)%frames;
    phase=hz==44100 ? (checked*147)%160 : 0;weight=(phase*8+2)/5;
    expected_l=sample(source_index,0);next_l=sample((source_index+1)%frames,0);
    expected_r=sample(source_index,nch==2 ? 1 : 0);next_r=sample((source_index+1)%frames,nch==2 ? 1 : 0);
    expected_l=expected_l+(((next_l-expected_l)*weight)>>>8);
    expected_r=expected_r+(((next_r-expected_r)*weight)>>>8);
    actual_l=$signed(left);actual_r=$signed(right);
    if(actual_l!=expected_l || actual_r!=expected_r)
     $fatal(1,"PCM mismatch bits=%0d ch=%0d rate=%0d n=%0d got=%0d,%0d expected=%0d,%0d",nbits,nch,hz,checked,actual_l,actual_r,expected_l,expected_r);
    checked=checked+1;
   end
  end
 end
 initial begin
  for(mode=0;mode<16;mode=mode+1) begin
   rst=1;monitoring=0;heard=0;checked=0;
   nbits=mode[0] ? 24 : 16;nch=mode[1] ? 2 : 1;hz=mode[2] ? 44100 : 48000;
   fixture();repeat(5) @(negedge clk);rst=0;start=1;@(negedge clk);start=0;monitoring=1;
   wait(checked>=217);@(negedge clk);monitoring=0;pause=1;checkpoint=1;
   @(negedge clk);checkpoint=0;
   start_cluster=9;start=1;pause=0;@(negedge clk);start=0;
   wait(status==1);wait(status==3);repeat(220000) @(negedge clk);
   if(left==0 || right==0) $fatal(1,"emergency music did not play");
   pause=1;resume_saved=1;start=1;start_cluster=2;
   @(negedge clk);start=0;resume_saved=0;pause=0;
   // Interrupt again before the original queue has refilled: checkpoint must survive.
   wait(status==1);@(negedge clk);pause=1;checkpoint=1;
   @(negedge clk);checkpoint=0;start_cluster=9;start=1;pause=0;
   @(negedge clk);start=0;repeat(1000)@(negedge clk);wait(status==3);
   repeat(220000)@(negedge clk);pause=1;resume_saved=1;start=1;start_cluster=2;
   @(negedge clk);start=0;resume_saved=0;pause=0;heard=0;monitoring=1;
   wait(checked>=650);@(negedge clk);monitoring=0;
   if(file_cluster!=2 || status!=3) $fatal(1,"original track not restored");
   $display("PASS resume %0d-bit %0d-channel %0dHz extensible=%0d: original samples 217..649 exact after different track, 48k output phase continuous",nbits,nch,hz,mode[3]);
  end
  $display("PASS all resume formats");$finish;
 end
 initial begin #1000000000;$fatal(1,"resume timeout status %0d",status);end
endmodule
