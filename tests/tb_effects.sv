`timescale 1ns/1ps
module tb_effects;
reg clk=0;always #20 clk=~clk;
reg rst=1,tick=0,vs=1,de=0;reg [23:0] rgb=24'h4080c0;
reg [3:0] sw=0;reg [5:0] gain=32;
reg av=0;reg [23:0] pcm=0;
wire ov,od;wire [23:0] op;
video_effects dut(.clk(clk),.rst(rst),.frame_tick(tick),.vs(vs),.de(de),.rgb(rgb),
 .gain(gain),.switches(sw),.volume_level(5'd20),.subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.subtitle_addr(),.mode_key(1'b1),.source_width(16'd641),.source_height(16'd479),
 .image_ready(1'b1),.scan_sector(32'd2048),.image_count(3'd4),.autoplay(1'b0),.status(4'd1),.audio_status(4'd3),.audio_valid(av),.audio_left(pcm),.audio_right(pcm),.out_vs(ov),.out_de(od),.out_rgb(op));
integer b,k,i,x,y,fd,pcount=0;reg render=0;reg [23:0] expected;
function integer channel;
 input integer c,br,co;integer q;
 begin
 q=c-128;
 case(co) 1:q=q/2;2:q=q+q/2;3:q=q*2;endcase
 q=q+128;
 case(br) 1:q=q+32;2:q=q+64;3:q=q-32;endcase
 channel=q<0 ? 0 : q>255 ? 255 : q;
 end
endfunction
always @(negedge clk) if(render && od) begin
 $fwrite(fd,"%02x%02x%02x\n",op[23:16],op[15:8],op[7:0]);pcount=pcount+1;
end
initial begin
 repeat(5) @(negedge clk);rst=0;force dut.mode=3;
 for(k=0;k<4;k=k+1) for(b=0;b<4;b=b+1) begin
  sw=k*4+b;repeat(4) @(negedge clk);tick=1;@(negedge clk);tick=0;
  de=1;repeat(7) @(negedge clk);#1;
  expected={8'(channel(64,b,k)),8'(channel(128,b,k)),8'(channel(192,b,k))};
  if(op!==expected || !od) $fatal(1,"color b=%0d c=%0d got %h expected %h",b,k,op,expected);
  de=0;repeat(5) @(negedge clk);
 end
 // Capture clean baseline waveform snapshot from real sample inputs.
 release dut.mode;sw=0;gain=32;vs=0;repeat(4) @(negedge clk);
 for(i=0;i<512;i=i+1) begin
  av=1;pcm=$rtoi(1800000.0*$sin(i*6.283185307/48));@(negedge clk);
 end
 if(!dut.wave_pending) $fatal(1,"waveform trigger/capture incomplete");
 force dut.next_mode=0;av=0;tick=1;@(negedge clk);tick=0;vs=1;
 repeat(8) @(negedge clk);
 fd=$fopen("effects_pixels.hex","w");render=1;
 for(y=0;y<480;y=y+1) begin
  for(x=0;x<640;x=x+1) begin
   de=1;rgb={8'(x*255/639),8'(y*255/479),8'(120)};@(negedge clk);
  end
  de=0;repeat(160) @(negedge clk);
 end
 repeat(10) @(negedge clk);render=0;$fclose(fd);
 if(pcount!=307200) $fatal(1,"pixel timing count %0d",pcount);
 $display("PASS effects: 16 brightness/contrast combinations, 307200 aligned pixels and PCM snapshot");$finish;
end
endmodule
