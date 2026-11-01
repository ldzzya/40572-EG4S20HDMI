`timescale 1ns/1ps
module tb_scaler;
reg clk=0;always #5 clk=~clk;
reg rst=1,scan_start=0,load_start=0;
wire ready,scan_done,found,err,req,read_req,valid;
wire [31:0] found_sector,addr;wire [2:0] count;wire [3:0] status;
wire [15:0] sw,sh;wire [23:0] pixel;
reg ack=0,wr_ready=1,dv=0,sec_end=0;reg [7:0] data=0;
reg [2047:0] fixture;reg [7:0] file_bytes[0:921653];integer fd,flen_actual,has_file=0;
integer iw,ih,off,bad,timeout_test,cycles=0,pixels=0,stride,flen;
integer sx,sy,ex;reg [23:0] expected;
bmp_read #(.TIMEOUT_CYCLES(20000)) dut(
 .clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),.scan_start_sector(0),
 .scan_max_sector(131071),.scan_target_count(3'd1),.scan_done(scan_done),
 .scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(count),
 .load_start(load_start),.load_sector(0),.sd_init_done(1'b1),.state_code(status),
 .bmp_width(16'd640),.bmp_height(16'd480),.source_width(sw),.source_height(sh),.load_error(err),
 .write_req(req),.write_req_ack(ack),.write_ready(wr_ready),.sd_sec_read(read_req),
 .sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(dv),
 .sd_sec_read_end(sec_end),.bmp_data_wr_en(valid),.bmp_data(pixel));
function [7:0] card_byte;
 input integer a;integer z,xx,yy,k;
 begin
 card_byte=0;
 case(a)
  0:card_byte=8'h42;1:card_byte=8'h4d;
  2,3,4,5:card_byte=flen>>((a-2)*8);
  10,11,12,13:card_byte=off>>((a-10)*8);
  14:card_byte=40;
  18,19,20,21:card_byte=iw>>((a-18)*8);
  22,23,24,25:card_byte=ih>>((a-22)*8);
  26:card_byte=1;28:card_byte=bad ? 16 : 24;
 endcase
 if(a>=off && a<flen) begin
  z=a-off;yy=z/stride;k=z%stride;xx=k/3;
  if(k>=iw*3) card_byte=8'hee;
  else case(k%3) 0:card_byte=xx;1:card_byte=yy;2:card_byte=xx^yy;endcase
 end
 if(has_file) card_byte=(a<flen_actual) ? file_bytes[a] : 0;
 end
endfunction
integer j,base,reads=0,load_reads,load_cycle,byte_gap=2;
initial forever begin
 @(negedge clk);
 if(read_req && !timeout_test) begin
  reads=reads+1;base=addr*512;
  repeat(3) @(negedge clk);
  for(j=0;j<512;j=j+1) begin
   data=card_byte(base+j);dv=1;@(negedge clk);dv=0;repeat(byte_gap-1) @(negedge clk);
  end
  sec_end=1;@(negedge clk);sec_end=0;
 end
end
always @(negedge clk) begin
 ack<=req;cycles=cycles+1;
 wr_ready<=cycles%31<23;
 if(valid) begin
  sx=(pixels%640)*iw/640;sy=(pixels/640)*ih/480;
  expected={8'((sx^sy)&255),8'(sy&255),8'(sx&255)};
  if(has_file) begin
   ex=off+sy*stride+sx*3;expected={file_bytes[ex+2],file_bytes[ex+1],file_bytes[ex]};
  end
  if(pixel!==expected) $fatal(1,"pixel %0d got %h expected %h source %0d %0d",pixels,pixel,expected,sx,sy);
  pixels=pixels+1;
 end
end
initial begin
 if($value$plusargs("BYTE_GAP=%d",byte_gap))begin end
 iw=320;ih=240;off=54;bad=0;timeout_test=0;
 if($value$plusargs("W=%d",iw))begin end
 if($value$plusargs("H=%d",ih))begin end
 if($value$plusargs("OFFSET=%d",off))begin end
 if($value$plusargs("BAD=%d",bad))begin end
 if($value$plusargs("TIMEOUT=%d",timeout_test))begin end
 if($value$plusargs("FILE=%s",fixture)) begin
  has_file=1;fd=$fopen(fixture,"rb");if(!fd) $fatal(1,"fixture open");
  flen_actual=$fread(file_bytes,fd);$fclose(fd);iw=640;ih=480;off=54;
 end
 stride=(iw*3+3)&~3;flen=off+stride*ih;
 repeat(10) @(negedge clk);rst=0;
 if(!bad && !timeout_test) begin
  scan_start=1;@(negedge clk);scan_start=0;
  wait(scan_done);repeat(3) @(negedge clk);
  if(count!=1 || found_sector!=0) $fatal(1,"scan failed");
 end
 load_reads=reads;load_cycle=cycles;load_start=1;@(negedge clk);load_start=0;
 wait(!ready);wait(ready);repeat(4) @(negedge clk);
 if(bad || timeout_test) begin
  if(pixels!=0 || status!=14) $fatal(1,"bad file / timeout not rejected");
 end else if(pixels!=307200 || sw!=iw || sh!=ih) $fatal(1,"wrong output count/size %0d",pixels);
 $display("PASS scaler %0dx%0d offset=%0d bad=%0d timeout=%0d pixels=%0d",iw,ih,off,bad,timeout_test,pixels);
 if(has_file) $display("PASS supplied example BMP: %0s",fixture);
 $display("PERF width=%0d height=%0d byte_gap=%0d sectors=%0d cycles=%0d",iw,ih,byte_gap,reads-load_reads,cycles-load_cycle);
 $finish;
end
initial begin #2000000000;$fatal(1,"simulation watchdog");end
endmodule
