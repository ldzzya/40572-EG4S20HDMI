`timescale 1ns/1ps
module tb_priority_controls;
 reg clk=0;always #10 clk=~clk;reg rst=1,tick=0;
 reg [3:0] sw=0,keys=15;wire [3:0] allowed;wire locked;
 priority_guard #(.DEBOUNCE_CYCLES(3)) guard(clk,sw[0],keys,locked,allowed);
 wire [2:0] page,selection;wire field;wire [3:0] settings;
 wire ni,au,mo,dn,up,mute,pause,visible,english,fit;wire [1:0] speed,tr;
 menu_controller #(.DEBOUNCE_CYCLES(2),.HOLD_CYCLES(30),.REPEAT_CYCLES(12),.SHORT_CYCLES(4))
  menu(clk,rst,tick,allowed[1],allowed[2],allowed[3],sw,page,selection,field,settings,ni,au,mo,dn,up,mute,pause,visible,speed,english,fit,tr,locked,);
 integer i,j,events=0;reg old_ni=1;
 always @(negedge clk) begin tick=~tick;if(old_ni && !ni)events=events+1;old_ni=ni;end
 always @(posedge clk) if(locked && (allowed!=15 || !ni || !au || !mo || dn || up))
  $fatal(1,"locked controls leaked");
 task press(input integer k);begin keys[k]=0;repeat(8) @(negedge clk);keys[k]=1;repeat(10) @(negedge clk);end endtask
 initial begin
  repeat(10) @(negedge clk);rst=0;press(2);if(page!=1)$fatal(1,"gallery entry");
  press(1);if(events!=1)$fatal(1,"normal next key");
  // Bounce shorter than the filter must not engage priority mode.
  sw[0]=1;@(negedge clk);sw[0]=0;repeat(8) @(negedge clk);if(locked)$fatal(1,"switch bounce");
  sw[0]=1;repeat(12) @(negedge clk);if(!locked)$fatal(1,"lock missing");
  for(i=0;i<8;i=i+1)begin
   sw={i[2:0],1'b1};keys=0;repeat(45) @(negedge clk);keys=15;repeat(12) @(negedge clk);
   if(page!=1 || settings!=0 || mute || !visible || pause || fit || tr || events!=1)
    $fatal(1,"locked state changed");
  end
  // KEY1 is held during unlock: must not reset or emit a delayed gesture.
  keys=0;sw[0]=0;repeat(50) @(negedge clk);
  if(locked || allowed!=15 || events!=1)$fatal(1,"held key escaped on unlock");
  keys=15;repeat(20) @(negedge clk);press(1);
  if(events!=2)$fatal(1,"normal operation not restored");
  for(i=0;i<8;i=i+1)begin sw={i[2:0],1'b0};repeat(10) @(negedge clk);if(settings!=0 || locked)$fatal(1,"unused switches still active");end
  keys[0]=0;#1;if(allowed[0]!=0)$fatal(1,"normal KEY1 reset disabled");keys[0]=1;
  $display("PASS priority controls: SW1 debounce, all four keys blocked including reset, SW2-4 inactive, settings retained, held-key unlock interlock, normal reset restored");$finish;
 end
endmodule
