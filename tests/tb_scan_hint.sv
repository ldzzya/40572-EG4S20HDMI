`timescale 1ns/1ps
module tb_scan_hint;
reg clk=0;always #5 clk=~clk;
reg rst=1,start=0,dv=0,ending=0;reg [7:0] data=0;
wire req,done;wire [31:0] address,found_sector,resume_sector;wire [2:0] count;
integer kind=0,reads=0,j,lba,target,expected_reads;
reg [31:0] scan_start_lba=0,scan_limit=8191;
bmp_read dut(.clk(clk),.rst(rst),.scan_start(start),.scan_start_sector(scan_start_lba),
 .scan_max_sector(scan_limit),.scan_target_count(3'd1),.scan_done(done),
 .scan_found_sector(found_sector),.scan_found_total(count),.scan_resume_sector(resume_sector),
 .load_start(1'b0),.load_sector(32'd0),.sd_init_done(1'b1),
 .bmp_width(16'd640),.bmp_height(16'd480),.write_req_ack(1'b0),.write_ready(1'b1),
 .sd_sec_read(req),.sd_sec_read_addr(address),.sd_sec_read_data(data),
 .sd_sec_read_data_valid(dv),.sd_sec_read_end(ending));
function [7:0] getbyte;
 input integer sec,idx;
 begin
 getbyte=0;
 if(sec==0 && kind!=3) case(idx)
  450:getbyte=8'h0c;455:getbyte=8'h08; // first partition starts at LBA 2048
  460:getbyte=8'h02; // 131072 sectors
  510:getbyte=(kind==2) ? 0 : 8'h55;511:getbyte=8'haa;
 endcase
 if((sec==2048 && kind!=3) || (sec==0 && kind==3)) case(idx)
  12:getbyte=(kind==1) ? 4 : 2; // invalid 1024-byte sectors must fall back
  13:getbyte=1;14:getbyte=32;16:getbyte=2;
  34:getbyte=2;36:getbyte=8'hf0;37:getbyte=3; // FAT size 1008
  44:getbyte=2;510:getbyte=8'h55;511:getbyte=8'haa;
 endcase
 if(sec==target) case(idx)
  0:getbyte="B";1:getbyte="M";2:getbyte=58;10:getbyte=54;14:getbyte=40;
  18:getbyte=1;22:getbyte=1;26:getbyte=1;28:getbyte=24;
 endcase
 end
endfunction
initial forever begin
 @(negedge clk);
 if(req) begin
  lba=address;reads=reads+1;
  if(kind==0 && !((reads==1 && lba==0)||(reads==2 && lba==2048)||(reads==3 && lba==4096)))
   $fatal(1,"unexpected FAT32 scan address %d read %d",lba,reads);
  for(j=0;j<512;j=j+1) begin data=getbyte(lba,j);dv=1;@(negedge clk);dv=0;@(negedge clk);end
  ending=1;@(negedge clk);ending=0;
 end
end
initial begin
 if($value$plusargs("KIND=%d",kind))begin end
 case(kind)
  0,4:begin target=4096;expected_reads=3;end
  1:begin target=2050;expected_reads=4;end
  2:begin target=2;expected_reads=3;end
  3:begin target=2048;expected_reads=2;end
 endcase
 if(kind==4) scan_limit=511;
 repeat(5) @(negedge clk);rst=0;start=1;@(negedge clk);start=0;
 wait(done);repeat(3) @(negedge clk);
 while(kind==4 && count==0) begin
  scan_start_lba=resume_sector;scan_limit=resume_sector+511;
  @(negedge clk);start=1;@(negedge clk);start=0;
  wait(!done);wait(done);repeat(3) @(negedge clk);
 end
 if(count!=1 || found_sector!=target || reads!=expected_reads || resume_sector!=target+1)
  $fatal(1,"scan hint failed kind=%d sector=%d reads=%d",kind,found_sector,reads);
 $display("PASS scan hint kind=%d sectors=%d target=%d",kind,reads,target);$finish;
end
initial begin #10000000;$fatal(1,"hint watchdog");end
endmodule
