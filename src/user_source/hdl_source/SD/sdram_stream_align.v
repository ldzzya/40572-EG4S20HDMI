// Calibrate whole-word timing, never RGB channel order. Probe storage is above
// all three framebuffers. Commands have a fixed two-cycle pipeline, allowing
// data to be selected from two cycles before through two cycles after nominal.
module sdram_stream_align #(
 parameter [20:0] PROBE_BASE=21'd2073600,
 parameter TIMEOUT_CYCLES=65535
)(
 input clk,rst,init_done,refresh_busy,controller_busy,
 input write_en,input [20:0] write_addr,input [31:0] write_data,input [3:0] write_mask,
 input read_en,input [20:0] read_addr,
 output ready,output [3:0] status,output [7:0] detail,output pipeline_busy,
 output memory_write_en,output [20:0] memory_write_addr,
 output [31:0] memory_write_data,output [3:0] memory_write_mask,
 output memory_read_en,output [20:0] memory_read_addr,
 input memory_read_valid,input [31:0] memory_read_data,
 output read_valid,output [31:0] read_data
);
 localparam WAIT_INIT=0,START=1,FIFO_RELEASE=2,FILL=3,WRITE_WAIT=4,WRITE=5,WRITE_DRAIN=6,
            READ_WAIT=7,READ=8,READ_DRAIN=9,CHECK=10,FINISHED=11,ABORT_DRAIN=12;
 reg [3:0] state;
 reg [2:0] trial_w,trial_r,selected_w,selected_r;
 reg complete,failed,timed_out,epoch;
 reg [7:0] filled,written,issued,received,bad_words,best_bad;
 reg [3:0] settle;
 reg [$clog2(TIMEOUT_CYCLES+1)-1:0] watchdog;
 reg [31:0] w1,w2,w3,w4,r1,r2,r3,r4;
 reg [1:0] wp,rp,vp;
 reg [20:0] wa1,wa2,ra1,ra2;
 reg [3:0] mask1,mask2;
 wire [31:0] probe_data;
 wire probe_write=state==WRITE;
 wire probe_read=state==READ;
 wire [31:0] unaligned_write=complete ? write_data : probe_data;
 wire [2:0] write_tap=complete ? selected_w : tap_order(trial_w);
 wire [2:0] read_tap=complete ? selected_r : tap_order(trial_r);
 wire [31:0] aligned_read=read_tap==0 ? memory_read_data :
                         read_tap==1 ? r1 : read_tap==2 ? r2 : read_tap==3 ? r3 : r4;
 wire available=init_done && !refresh_busy && !controller_busy && !pipeline_busy;
 wire capture=(state==READ || state==READ_DRAIN) && vp[1];

 function [2:0] tap_order;
  input [2:0] n;
  begin case(n)0:tap_order=2;1:tap_order=3;2:tap_order=1;3:tap_order=4;default:tap_order=0;endcase end
 endfunction
 function [31:0] probe_word;
  input [7:0] index;
  reg [7:0] a,b,c,d;
  begin
   a=index^8'hb3;b=index+8'h17;c=~index;d={index[3:0],index[7:4]}^8'ha6;
   probe_word={a,b,c,d} ^ (epoch ? 32'hffffffff : 32'd0);
  end
 endfunction

 wfifo_32_32_512 probe_fifo(.clkr(clk),.clkw(clk),.rst(rst || state==START),
  .we(state==FILL),.di(probe_word(filled)),.re(probe_write),.dout(probe_data),
  .empty_flag(),.full_flag(),.wrusedw(),.rdusedw());

 assign ready=complete && init_done;
 // C: calibrating; 0: two independent patterns passed; F: mismatched words;
 // E: missing response/timeout. Detail is successful W/R taps or minimum bad
 // word count (hex), or the timed-out FSM state. Existing right 3 digits stay.
 assign status=timed_out ? 4'he : failed ? 4'hf : complete ? 4'h0 : 4'hc;
 assign detail=failed ? best_bad : {1'b0,selected_w,1'b0,selected_r};
 assign pipeline_busy=(|wp)||(|rp)||(|vp);
 assign memory_write_en=wp[1];
 assign memory_write_addr=wa2;
 assign memory_write_data=write_tap==0 ? unaligned_write :
                          write_tap==1 ? w1 : write_tap==2 ? w2 : write_tap==3 ? w3 : w4;
 assign memory_write_mask=mask2;
 assign memory_read_en=rp[1];
 assign memory_read_addr=ra2;
 assign read_valid=complete && vp[1];
 assign read_data=aligned_read;

 always @(posedge clk or posedge rst)begin
  if(rst)begin
   w1<=0;w2<=0;w3<=0;w4<=0;r1<=0;r2<=0;r3<=0;r4<=0;
   wp<=0;rp<=0;vp<=0;wa1<=0;wa2<=0;ra1<=0;ra2<=0;mask1<=0;mask2<=0;
  end else begin
   w1<=unaligned_write;w2<=w1;w3<=w2;w4<=w3;
   r1<=memory_read_data;r2<=r1;r3<=r2;r4<=r3;
   wp<={wp[0],complete ? write_en : probe_write};
   rp<={rp[0],complete ? read_en : probe_read};
   vp<={vp[0],memory_read_valid};
   wa1<=complete ? write_addr : PROBE_BASE+written;wa2<=wa1;
   ra1<=complete ? read_addr : PROBE_BASE+issued;ra2<=ra1;
   mask1<=complete ? write_mask : 4'd0;mask2<=mask1;
  end
 end
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=WAIT_INIT;trial_w<=0;trial_r<=0;selected_w<=2;selected_r<=2;
   complete<=0;failed<=0;timed_out<=0;epoch<=0;
   filled<=0;written<=0;issued<=0;received<=0;bad_words<=0;best_bad<=255;
   settle<=0;watchdog<=0;
  end else begin
   if(state==WAIT_INIT || state==START || complete)watchdog<=0;
   else watchdog<=watchdog+1'b1;
   if(capture)begin
    // An unknown value is a failure in simulation as well as a mismatched word.
    if(received<128 && aligned_read==probe_word(received))begin end
    else if(bad_words!=255)bad_words<=bad_words+1'b1;
    if(received!=255)received<=received+1'b1;
   end
   if(state!=WAIT_INIT && state!=ABORT_DRAIN && !complete && watchdog==TIMEOUT_CYCLES-1)begin
    failed<=1;timed_out<=1;best_bad<={4'd0,state};
    selected_w<=2;selected_r<=2;settle<=12;state<=ABORT_DRAIN;
   end else case(state)
    WAIT_INIT:if(available)state<=START;
    START:begin
     filled<=0;written<=0;issued<=0;received<=0;bad_words<=0;settle<=12;state<=FIFO_RELEASE;
    end
    FIFO_RELEASE:if(settle!=0)settle<=settle-1'b1;else state<=FILL;
    FILL:begin filled<=filled+1'b1;if(filled==127)state<=WRITE_WAIT;end
    WRITE_WAIT:if(available)state<=WRITE;
    WRITE:begin
     written<=written+1'b1;
     // Test both 64+64 writes / 128 read and 128 write / 64+64 reads.
     if(written==127 || (!epoch && written==63))begin settle<=12;state<=WRITE_DRAIN;end
    end
    WRITE_DRAIN:begin
     if(settle!=0)settle<=settle-1'b1;
     else if(available)state<=written==128 ? READ_WAIT : WRITE_WAIT;
    end
    READ_WAIT:if(available)state<=READ;
    READ:begin
     issued<=issued+1'b1;
     if(issued==127 || (epoch && issued==63))begin settle<=12;state<=READ_DRAIN;end
    end
    READ_DRAIN:begin
     if(settle!=0)settle<=settle-1'b1;
     else if(available && received>=issued)state<=issued==128 ? CHECK : READ_WAIT;
    end
    CHECK:begin
     if(bad_words==0 && received==128)begin
      if(!epoch)begin epoch<=1;state<=START;end
      else begin selected_w<=tap_order(trial_w);selected_r<=tap_order(trial_r);complete<=1;state<=FINISHED;end
     end else begin
      if(bad_words<best_bad)best_bad<=bad_words;
      epoch<=0;
      if(trial_w==4 && trial_r==4)begin failed<=1;complete<=1;state<=FINISHED;end
      else begin
       if(trial_r==4)begin trial_r<=0;trial_w<=trial_w+1'b1;end
       else trial_r<=trial_r+1'b1;
       state<=START;
      end
     end
    end
    ABORT_DRAIN:begin
     if(settle!=0)settle<=settle-1'b1;
     else if(available)begin complete<=1;state<=FINISHED;end
    end
    FINISHED:state<=FINISHED;
    default:begin state<=WAIT_INIT;complete<=0;selected_w<=2;selected_r<=2;end
   endcase
  end
 end
endmodule
