`timescale 1ns/1ps
module tb_scaler_720;
reg clk=0;always #5 clk=~clk;
reg rst=1,scan_start=0,load_start=0;
wire ready,scan_done,found,err,req,read_req,valid;
wire [31:0] found_sector,addr;wire [2:0] count;wire [3:0] status;
wire [15:0] sw,sh;wire [23:0] pixel;
reg ack=0,wr_ready=1,dv=0,sec_end=0;reg [7:0] data=0;
reg [2047:0] fixture;reg [7:0] file_bytes[0:8388607];integer fd,flen_actual,has_file=0;
integer fit=0,vw,vh,leftbar,bottom,px,py;
integer iw,ih,off,bad,timeout_test,cycles=0,pixels=0,stride,flen;
integer sx,sy,ex,sx1,sy1,wx,wy,xstep,ystep,xp,yp,pattern_kind=0;
integer dump_fd=0;reg [2047:0] dump_path;
integer sequence_test=0,pass;
reg [23:0] expected;
bmp_read #(.OUT_W(1280),.OUT_H(720),.TIMEOUT_CYCLES(20000)) dut(
 .aspect_fit(fit!=0),.clk(clk),.rst(rst),.ready(ready),.scan_start(scan_start),.scan_start_sector(0),
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
  14:card_byte=bad==2 ? 124 : 40;
  18,19,20,21:card_byte=iw>>((a-18)*8);
  22,23,24,25:card_byte=ih>>((a-22)*8);
  26:card_byte=1;28:card_byte=bad==1 ? 16 : 24;
  30:card_byte=bad==5 ? 1 : 0;
 endcase
 if(a>=off && a<flen) begin
  z=a-off;yy=z/stride;k=z%stride;xx=k/3;
  if(k>=iw*3) card_byte=8'hee;
  else if(pattern_kind==1) card_byte=((xx/9+yy/7)%2) ? 255 : 0;
  else case(k%3) 0:card_byte=xx;1:card_byte=yy;2:card_byte=xx^yy;endcase
 end
 if(has_file) card_byte=(a<flen_actual) ? file_bytes[a] : 0;
 end
endfunction
function integer reference_channel(input integer xx,yy,c);
 reference_channel=card_byte(off+yy*stride+xx*3+c);
endfunction
function integer reference_blend(input integer a,b,f);
 reference_blend=(a*(256-f)+b*f+128)/256;
endfunction
function [7:0] reference_bilinear(input integer c);
 integer low,high;
 begin
 low=reference_blend(reference_channel(sx,sy,c),reference_channel(sx1,sy,c),wx);
 high=reference_blend(reference_channel(sx,sy1,c),reference_channel(sx1,sy1,c),wx);
 reference_bilinear=reference_blend(low,high,wy);
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
  sx=(pixels%1280)*iw/1280;sy=(pixels/1280)*ih/720;
  expected={8'((sx^sy)&255),8'(sy&255),8'(sx&255)};
  if(has_file) begin
   ex=off+sy*stride+sx*3;expected={file_bytes[ex+2],file_bytes[ex+1],file_bytes[ex]};
  end
  if(pattern_kind==1) expected={3{8'(reference_channel(sx,sy,0))}};
  if(iw<=1280 && ih<=720 && (iw<1280 || ih<720)) begin
   xstep=((iw-1)*65536)/1279;ystep=((ih-1)*65536)/719;
   xp=(pixels%1280)==1279 ? (iw-1)*65536 : (pixels%1280)*xstep;
   yp=(pixels/1280)==719 ? (ih-1)*65536 : (pixels/1280)*ystep;
   sx=xp/65536;sy=yp/65536;sx1=(sx+1<iw) ? sx+1 : sx;sy1=(sy+1<ih) ? sy+1 : sy;
   wx=(xp/256)%256;wy=(yp/256)%256;
   expected={reference_bilinear(2),reference_bilinear(1),reference_bilinear(0)};
  end
  if(fit!=0) begin
   vw=iw*720>=ih*1280 ? 1280 : iw*720/ih;if(vw<1) vw=1;
   vh=iw*720>=ih*1280 ? ih*1280/iw : 720;if(vh<1) vh=1;
   leftbar=(1280-vw)/2;bottom=(720-vh)/2;px=pixels%1280-leftbar;py=pixels/1280-bottom;
   if(px<0 || px>=vw || py<0 || py>=vh) expected=0;
   else begin sx=px*iw/vw;sy=py*ih/vh;expected={8'((sx^sy)&255),8'(sy&255),8'(sx&255)};end
  end
  if(pixel!==expected) $fatal(1,"pixel %0d got %h expected %h source %0d %0d",pixels,pixel,expected,sx,sy);
  if(dump_fd) $fwrite(dump_fd,"%06x\n",pixel);
  pixels=pixels+1;
 end
end
initial begin
 if($value$plusargs("BYTE_GAP=%d",byte_gap))begin end
 if($value$plusargs("FIT=%d",fit))begin end
 iw=320;ih=240;off=54;bad=0;timeout_test=0;
 if($value$plusargs("W=%d",iw))begin end
 if($value$plusargs("H=%d",ih))begin end
 if($value$plusargs("OFFSET=%d",off))begin end
 if($value$plusargs("BAD=%d",bad))begin end
 if(bad==4) iw=1921;
 if($value$plusargs("TIMEOUT=%d",timeout_test))begin end
 if($value$plusargs("PATTERN=%d",pattern_kind))begin end
 if($value$plusargs("SEQUENCE=%d",sequence_test))begin end
 if($value$plusargs("DUMP=%s",dump_path)) dump_fd=$fopen(dump_path,"w");
 if($value$plusargs("FILE=%s",fixture)) begin
  has_file=1;fd=$fopen(fixture,"rb");if(!fd) $fatal(1,"fixture open");
  flen_actual=$fread(file_bytes,fd);$fclose(fd);
  iw={file_bytes[21],file_bytes[20],file_bytes[19],file_bytes[18]};
  ih={file_bytes[25],file_bytes[24],file_bytes[23],file_bytes[22]};
  off={file_bytes[13],file_bytes[12],file_bytes[11],file_bytes[10]};
 end
 stride=(iw*3+3)&~3;flen=off+stride*ih;
 if(bad==3) flen=flen-1;
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
 end else if(pixels!=921600 || sw!=iw || sh!=ih) $fatal(1,"wrong output count/size %0d",pixels);
 $display("PASS scaler %0dx%0d offset=%0d bad=%0d timeout=%0d pixels=%0d",iw,ih,off,bad,timeout_test,pixels);
 if(has_file) $display("PASS supplied example BMP: %0s",fixture);
 $display("PERF width=%0d height=%0d byte_gap=%0d sectors=%0d cycles=%0d",iw,ih,byte_gap,reads-load_reads,cycles-load_cycle);
 if(dump_fd) $fclose(dump_fd);
 if(sequence_test) begin
  for(pass=0;pass<3;pass=pass+1) begin
   case(pass) 0:begin iw=1280;ih=720;end 1:begin iw=161;ih=123;end 2:begin iw=1;ih=1;end endcase
   stride=(iw*3+3)&~3;flen=off+stride*ih;pixels=0;dump_fd=0;
   load_start=1;@(negedge clk);load_start=0;
   wait(!ready);wait(ready);repeat(4) @(negedge clk);
   if(pixels!=921600 || sw!=iw || sh!=ih || status!=1) $fatal(1,"reload failed %0dx%0d",iw,ih);
  end
  $display("PASS mixed-size sequence: 320x240 -> 640x480 -> 161x123 -> 1x1 without reset, 1228800 pixels verified");
 end
 $finish;
end
initial begin #2000000000;$fatal(1,"simulation watchdog");end
endmodule
