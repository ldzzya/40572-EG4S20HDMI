`timescale 1ns/1ps
module tb_menu_render;
reg clk=0;always #5 clk=~clk;
reg [9:0] x=0,y=0;reg [2:0] page=0;reg english=0;
wire [2:0] style,ink;wire [1:0] coverage;wire [6:0] addr;
menu_overlay dut(.clk(clk),.x(x),.y(y),.page(page),.selection(3'd0),.field(1'b0),.settings(4'd0),
 .audio_status(4'd3),.volume(5'd12),.muted(1'b0),.paused(1'b0),.visible(1'b1),.speed(2'd1),.status(4'd1),.updates(4'd3),.images(3'd4),
 .ready(1'b1),.autoplay(1'b1),.gallery_clean(1'b0),.width_bcd(16'h1280),.height_bcd(16'h0720),
 .english(english),.aspect_fit(1'b1),.transition(2'd1),.display_mode(2'd0),.subtitle_active(1'b0),.subtitle_char(8'd32),.scroll(10'd0),.uptime(24'h012345),
 .subtitle_addr(addr),.style(style),.ink(ink),.coverage(coverage));
integer l,p,xx,yy,f,aa,filled;string path;
initial begin
 for(l=0;l<2;l=l+1) for(p=0;p<7;p=p+1) begin
  english=l;page=p;aa=0;filled=0;path=$sformatf("build/menu_sim/ui_%0d_%0d.hex",l,p);f=$fopen(path,"w");
  for(yy=0;yy<480;yy=yy+1) for(xx=0;xx<640;xx=xx+1) begin
   @(negedge clk);x=xx;y=yy;repeat(6)@(posedge clk);#1;
   if((^style===1'bx) || (^ink===1'bx) || (^coverage===1'bx)) $fatal(1,"unknown UI pixel %d %d",xx,yy);
   if(coverage==1 || coverage==2) aa=aa+1;if(coverage!=0) filled=filled+1;
   $fwrite(f,"%02x\n",{style,ink,coverage});
  end
  $fclose(f);if(aa<100 || filled<200) $fatal(1,"missing antialiasing page %d",p);
 end
 $display("PASS menu render: all 14 CN/EN pages, defined pixels and four-level antialiasing");$finish;
end
endmodule

