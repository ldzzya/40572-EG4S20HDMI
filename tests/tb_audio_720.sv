`timescale 1ns/1ps
module tb_audio_720;
 reg clk=0;always #5 clk=~clk;reg rst=1;wire valid,room;wire [23:0] left,right;
 integer cycles=0,samples=0,first_sample=0;
 wav_pcm_48k #(.CLOCK_HZ(74250000)) dut(.clk(clk),.rst(rst),.flush(1'b0),.enable(1'b1),.rate_44100(1'b0),
 .push(room && !rst),.in_left(24'h123400),.in_right(24'hfedc00),.room(room),.valid(valid),.left(left),.right(right),
 .pause_playback(1'b0),.checkpoint(1'b0),.restore_context(1'b0));
 always @(negedge clk) if(!rst)begin
  cycles=cycles+1;if(valid)begin
   samples=samples+1;if(samples==1)first_sample=cycles;
   if(left!==24'h123400 || right!==24'hfedc00)$fatal(1,"audio sample corrupted");
  end
  if(samples==4801)begin
   if(cycles-first_sample!=7425000)$fatal(1,"48k cadence changed: %d",cycles-first_sample);
   $display("PASS 720p audio: 4800 samples per 7425000 video clocks, exactly 48kHz output");$finish;
  end
 end
 initial begin repeat(8)@(posedge clk);#1;rst=0;end
endmodule
