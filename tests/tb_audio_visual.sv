`timescale 1ns/1ps
module tb_audio_visual;
reg clk=0,rst=1,tick=0,vs=1,de=0,iv=0,up=0,down=0;
always #20 clk=~clk;
reg signed [23:0] sample=0;wire av;wire[23:0] pcm,pcm_r;wire[4:0] level;
reg[23:0] rgb;wire ov,od;wire[23:0] pixel;
reg rx=1;wire tx,custom,changed;wire[6:0] addr;wire[7:0] ch;wire[3:0] updates;
subtitle_uart captions(clk,rst,rx,tick,addr,ch,custom,changed,tx,updates);
audio_volume volume(clk,rst,down,up,iv,sample,sample,av,pcm,pcm_r,level,1'b0);
video_effects dut(.clk(clk),.rst(rst),.frame_tick(tick),.vs(vs),.de(de),.rgb(rgb),
 .gain(6'd32),.switches(4'd0),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
 .status(4'd1),.image_ready(1'b1),.scan_sector(32'd2048),.image_count(3'd4),.autoplay(1'b1),
 .audio_status(4'd3),.audio_valid(av),.audio_left(pcm),.audio_right(pcm),.volume_level(level),.subtitle_active(custom),.subtitle_char(ch),
 .subtitle_changed(changed),.subtitle_addr(addr),.out_vs(ov),.out_de(od),.out_rgb(pixel));
integer i,j,k,x,y,lo,hi,span100,span50,fd,count=0;reg render=0;
reg[23:0] photo[0:307199];
task frame;begin tick=1;@(negedge clk);tick=0;end endtask
task serial_byte(input[7:0] b);integer a;begin
 rx=0;repeat(217) @(negedge clk);
 for(a=0;a<8;a=a+1) begin rx=b[a];repeat(217) @(negedge clk);end
 rx=1;repeat(217) @(negedge clk);
end endtask
task caption(input string s);integer a;begin
 for(a=0;a<s.len();a=a+1) serial_byte(s[a]);serial_byte(10);repeat(8) @(negedge clk);frame();
end endtask
task capture;
 begin
  for(j=0;j<16384;j=j+1) begin
   sample=$rtoi(2000000.0*$sin(j*6.283185307/48));iv=1;@(negedge clk);
   iv=0;@(negedge clk);
   if(j%1024==1023) frame();
  end
  frame();lo=127;hi=0;
  for(j=0;j<256;j=j+1) begin
   if(dut.wave_ram[{dut.rd_bank,8'(j)}]<lo) lo=dut.wave_ram[{dut.rd_bank,8'(j)}];
   if(dut.wave_ram[{dut.rd_bank,8'(j)}]>hi) hi=dut.wave_ram[{dut.rd_bank,8'(j)}];
  end
 end
endtask
always @(negedge clk) if(render && od) begin
 if($isunknown(pixel)) $fatal(1,"unknown visualizer pixel");
 $fwrite(fd,"%06x\n",pixel);count=count+1;
end
task render_frame(input string name);
 begin
  vs=0;de=0;repeat(8) @(negedge clk);vs=1;
  fd=$fopen(name,"w");render=1;count=0;
  for(y=0;y<480;y=y+1) begin
   for(x=0;x<640;x=x+1) begin de=1;rgb=photo[y*640+x];@(negedge clk);end
   de=0;repeat(160) @(negedge clk);
  end
  repeat(10) @(negedge clk);render=0;$fclose(fd);
  if(count!=307200) $fatal(1,"frame pixel count");
 end
endtask
initial begin
 $readmemh("preview_photo.hex",photo);
 repeat(8) @(negedge clk);rst=0;
 caption("TEXT Welcome to FPGA Gallery | USB live subtitles");
 if(!custom || updates!=1 || dut.scroll!=0) $fatal(1,"UART-to-screen commit/reset scroll");
 capture();span100=hi-lo;
 if(span100<59 || span100>63) $fatal(1,"100 percent waveform span %0d",span100);
 render_frame("preview_100.hex");
 for(i=0;i<10;i=i+1) begin down=1;@(negedge clk);down=0;@(negedge clk);end
 capture();span50=hi-lo;
 if(span50<29 || span50>33 || span50>=span100) $fatal(1,"wave does not follow actual volume");
 render_frame("preview_050.hex");
 for(i=0;i<10;i=i+1) begin down=1;@(negedge clk);down=0;@(negedge clk);end
 capture();if(lo!=40 || hi!=40 || pcm!=0 || dut.peak_display!=0) $fatal(1,"mute not flat/zero");
 render_frame("preview_000.hex");
 $display("PASS audio visual: actual post-gain PCM wave spans %0d / %0d / 0; UART text visible, 3 full frames, zero mute meter",span100,span50);$finish;
end
endmodule
