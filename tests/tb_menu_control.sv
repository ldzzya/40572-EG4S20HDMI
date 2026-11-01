`timescale 1ns/1ps
module tb_menu_control;
reg clk=0,rst=1,tick=0;always #20 clk=~clk;
reg [2:0] keys=7;reg [3:0] sw=0;
wire [2:0] page,selection;wire field;wire [3:0] settings;
wire playback;wire image_n,auto_n,mode_n,dn,up,mute,pause,visible,english,fit;wire [1:0] speed,transition;
menu_controller #(.DEBOUNCE_CYCLES(2),.HOLD_CYCLES(30),.REPEAT_CYCLES(12),.SHORT_CYCLES(4))
 dut(clk,rst,tick,keys[0],keys[1],keys[2],sw,page,selection,field,settings,image_n,auto_n,mode_n,dn,up,mute,pause,visible,speed,english,fit,transition,1'b0,playback);
wire av;wire [23:0] pcm,pcm_r;wire [4:0] level;
audio_volume gain(clk,rst,dn,up,1'b1,24'sd2000000,24'sd2000000,av,pcm,pcm_r,level,mute);
integer pics=0,autos=0,modes=0;reg old_i=1,old_a=1,old_m=1;
always @(negedge clk) begin
 if(!rst && !playback) $fatal(1,"menu navigation paused live media");
 if(old_i && !image_n) pics=pics+1;if(old_a && !auto_n) autos=autos+1;if(old_m && !mode_n) modes=modes+1;
 old_i=image_n;old_a=auto_n;old_m=mode_n;
end
task press(input integer k);begin keys[k]=0;repeat(8) @(negedge clk);keys[k]=1;repeat(10) @(negedge clk);end endtask
task frame;begin tick=1;@(negedge clk);tick=0;@(negedge clk);end endtask
task home;begin keys[1]=0;repeat(85) @(negedge clk);keys[1]=1;repeat(12) @(negedge clk);frame();if(!playback || page!=0 || selection!=0) $fatal(1,"home/reset selection");end endtask
initial begin
 repeat(8) @(negedge clk);rst=0;frame();if(!playback || page!=1) $fatal(1,"automatic startup");home();
 if(!playback || page!=0 || english || fit || transition || settings!=0) $fatal(1,"boot defaults");
 press(0);if(selection!=0) $fatal(1,"selection tore frame");frame();if(selection!=4) $fatal(1,"home wrap");
 press(1);if(!english) $fatal(1,"language switch");press(1);if(english) $fatal(1,"language return");
 press(2);press(1);frame();if(!playback || page!=1) $fatal(1,"gallery");
 press(0);press(2);press(1);home();if(pics!=1 || autos!=1 || modes!=1) $fatal(1,"old gallery controls");
 press(2);press(1);frame();if(!playback || page!=6 || selection!=0) $fatal(1,"playback settings");
 press(1);if(!fit) $fatal(1,"ratio");press(2);press(1);if(transition!=1) $fatal(1,"curtain");press(1);if(transition!=2) $fatal(1,"cut");press(1);if(transition!=0) $fatal(1,"fade");
 press(2);press(1);press(2);press(1);press(2);press(1);frame();if(page!=3) $fatal(1,"audio hierarchy");
 press(0);repeat(50) @(negedge clk);if(level!=19) $fatal(1,"volume decrement");
 press(1);repeat(300) @(negedge clk);if(!mute || pcm!=0 || level!=19) $fatal(1,"mute retained level");
 press(1);repeat(300) @(negedge clk);if(mute || pcm==0) $fatal(1,"unmute");home();
 press(2);press(2);press(1);frame();if(page!=2) $fatal(1,"display hierarchy");
 press(1);if(settings[1:0]!=1) $fatal(1,"brightness");press(2);press(1);if(settings[3:2]!=2) $fatal(1,"contrast");
 sw=4'b0010;repeat(8) @(negedge clk);if(settings!=4'b1001) $fatal(1,"removed switches changed settings");
 press(2);press(1);frame();if(page!=4) $fatal(1,"captions hierarchy");
 press(0);press(2);press(1);if(!pause || visible || speed!=2) $fatal(1,"caption controls");home();
 repeat(3) press(2);press(1);frame();if(page!=5) $fatal(1,"status");press(0);press(1);press(2);home();
 if(pics!=2 || autos!=2 || modes!=1 || !fit || level!=19 || !pause || visible) $fatal(1,"isolated actions and retained settings");
 rst=1;@(negedge clk);if(page!=1 || !playback || fit || english || pause || !visible) $fatal(1,"reset");
 $display("PASS menu control: hierarchy, CN/EN, ratio/effects, legacy gallery, audio, captions, switches, frame latch and reset");$finish;
end
endmodule
