`timescale 1ns/1ps
module tb_overlay;
reg clk=0;always #20 clk=~clk;
reg rst=1,tick=0,ready=1,de=1;reg [5:0] gain=32;
wire ov,od;wire [23:0] out;
video_effects dut(.clk(clk),.rst(rst),.frame_tick(tick),.vs(1'b1),.de(de),.rgb(24'hc86432),
 .gain(gain),.switches(4'd0),.volume_level(5'd20),.subtitle_active(1'b0),.subtitle_char(8'd32),.subtitle_changed(1'b0),.subtitle_addr(),.mode_key(1'b1),.source_width(16'd640),.source_height(16'd480),
 .status(4'd2),.image_ready(ready),.scan_sector(32'h12345678),.image_count(3'd2),.autoplay(1'b1),
 .audio_status(4'd3),.audio_valid(1'b0),.audio_left(24'd0),.audio_right(24'd0),.out_vs(ov),.out_de(od),.out_rgb(out));
task frame;
 begin @(negedge clk);tick=1;@(negedge clk);tick=0;end
endtask
integer i;reg [23:0] expected;
initial begin
 repeat(5) @(negedge clk);rst=0;
 force dut.x=10'd100;force dut.y=10'd100;
 for(i=0;i<=32;i=i+1) begin
  gain=i;repeat(6) @(negedge clk);
  expected={8'(200*i/32),8'(100*i/32),8'(50*i/32)};
  if(out!==expected || !od) $fatal(1,"fade level %d: %h expected %h",i,out,expected);
 end
 ready=0;gain=0;repeat(6) @(negedge clk);
 if(out===24'd0 || $isunknown(out)) $fatal(1,"boot diagnostics invisible without picture");
 force dut.mode=3;force dut.y=10'd56;#1;
 if(!dut.panel || !dut.text_area) $fatal(1,"diagnostics hidden by OSD-off before first image");
 ready=1;force dut.status_snapshot=14;#1;
 if(!dut.panel || !dut.text_area) $fatal(1,"read error hidden in clean-picture mode");
 force dut.mode=2;#1;
 if(!dut.panel || !dut.text_area) $fatal(1,"read error hidden in waveform mode");
 release dut.status_snapshot;
 release dut.mode;release dut.x;release dut.y;de=0;
 // 640 frame ticks must wrap exactly once; no horizontal motion inside a frame.
 for(i=0;i<640;i=i+1) begin
  if(dut.scroll!=i) $fatal(1,"ticker position %d vs %d",dut.scroll,i);
  repeat(4) @(negedge clk);
  if(dut.scroll!=i) $fatal(1,"ticker moved within frame");
  frame();
 end
 if(dut.scroll!=0) $fatal(1,"ticker wrap");
 if(dut.status_snapshot!=2 || dut.sector_snapshot!=32'h12345678 || dut.count_snapshot!=2)
  $fatal(1,"status snapshot");
 force dut.seconds_div=24999999;
 @(negedge clk);release dut.seconds_div;
 if(dut.time_snapshot!=0) $fatal(1,"timestamp changed within frame");
 frame();
 if(dut.time_snapshot==0) $fatal(1,"timestamp not updated at frame boundary");
 $display("PASS overlay: 33 fade endpoints, no-card/error diagnostics in all modes, 640 one-pixel scroll steps and frame-latched timestamp/status");
 $finish;
end
endmodule
