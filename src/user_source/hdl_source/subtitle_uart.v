// 115200 baud, 8N1. TEXT <0..80 printable ASCII characters><LF>.
// CR is ignored for CRLF terminals. Reply K=frame committed, E=bad line,
// B=busy (retry after K). Unterminated lines expire after one second.
// Two text banks: incoming bytes can never overwrite the visible subtitle.
module subtitle_uart #(parameter CLOCK_HZ=25000000,parameter BAUD=115200)(
 input clk,rst,rx,frame_tick,input [6:0] text_addr,
 output [7:0] text_char,output custom_active,output text_changed,
 output tx,output reg [3:0] update_count
);
 localparam DIV=(CLOCK_HZ+BAUD/2)/BAUD;
 wire [7:0] data;
 wire valid,framing_error;
 uart_rx_byte #(.DIV(DIV)) receiver(clk,rst,rx,data,valid,framing_error);
 reg [7:0] memory[0:255];
 reg bank,active,pending,bad,busy_line;
 reg [6:0] visible_length,pending_length,length;
 reg [2:0] prefix;
 reg [$clog2(CLOCK_HZ)-1:0] timeout_count;
 reg [7:0] reply;
 reg reply_valid;
 wire tx_busy;
 // A frame commit and an invalid/busy line may finish together. Queue both
 // acknowledgements rather than losing a one-cycle pulse while TX is busy.
 reg [7:0] replies[0:3];
 reg [1:0] reply_wr,reply_rd;
 reg [2:0] reply_count;
 wire reply_pop=reply_count!=0 && !tx_busy;
 wire commit_reply=pending && frame_tick;
 wire [2:0] slots=3'd4-reply_count+reply_pop;
 wire push_commit=commit_reply && slots!=0;
 wire push_error=reply_valid && slots>{2'b0,push_commit};
 wire [1:0] pushes={1'b0,push_commit}+{1'b0,push_error};
 uart_tx_byte #(.DIV(DIV)) transmitter(clk,rst,replies[reply_rd],reply_pop,tx,tx_busy);
 always @(posedge clk or posedge rst) begin
  if(rst) begin reply_wr<=0;reply_rd<=0;reply_count<=0;end
  else begin
   if(push_commit) replies[reply_wr]<="K";
   if(push_error) replies[(reply_wr+push_commit)&2'b11]<=reply;
   reply_wr<=reply_wr+pushes;
   if(reply_pop) reply_rd<=reply_rd+1'b1;
   reply_count<=reply_count+pushes-reply_pop;
  end
 end
 assign custom_active=active;
 assign text_changed=pending && frame_tick;
 assign text_char=(text_addr<visible_length) ? memory[{bank,text_addr}] : 8'd32;
 always @(posedge clk) begin
  if(!rst && valid && data>=32 && data<=126 && prefix==5 && !bad && !busy_line && !pending && length<80)
   memory[{~bank,length}]<=data;
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin bank<=0;active<=0;pending<=0;bad<=0;busy_line<=0;
   visible_length<=0;pending_length<=0;length<=0;prefix<=0;timeout_count<=0;
   reply<=0;reply_valid<=0;update_count<=0;end
  else begin
   reply_valid<=0;
   if(pending && frame_tick) begin
    bank<=~bank;active<=1;pending<=0;visible_length<=pending_length;
    update_count<=update_count+1'b1;
   end
   // A byte arriving exactly at the idle deadline continues the line.
   if((prefix!=0 || bad || busy_line) && !valid && !framing_error) begin
    if(timeout_count==CLOCK_HZ-1) begin
     prefix<=0;length<=0;bad<=0;busy_line<=0;timeout_count<=0;reply<="E";reply_valid<=1;
    end else timeout_count<=timeout_count+1'b1;
   end
   if(framing_error) begin bad<=1;timeout_count<=0;end
   if(valid) begin
    timeout_count<=0;
    if(data==10) begin
     if(busy_line || pending) begin reply<="B";reply_valid<=1;end
     else if(bad || prefix!=5) begin reply<="E";reply_valid<=1;end
     else begin pending<=1;pending_length<=length;end
     prefix<=0;length<=0;bad<=0;busy_line<=0;
    end else if(data!=13) begin
     if(pending) busy_line<=1;
     if(!bad && !busy_line && !pending) begin
      case(prefix)
       0:if(data=="T") prefix<=1;else bad<=1;
       1:if(data=="E") prefix<=2;else bad<=1;
       2:if(data=="X") prefix<=3;else bad<=1;
       3:if(data=="T") prefix<=4;else bad<=1;
       4:if(data==" ") prefix<=5;else bad<=1;
       5:if(data<32 || data>126 || length==80) bad<=1;else length<=length+1'b1;
       default:bad<=1;
      endcase
     end
    end
   end
  end
 end
endmodule

module uart_rx_byte #(parameter DIV=217)(input clk,rst,rx,
 output reg [7:0] data,output reg valid,framing_error);
 reg [1:0] sync;
 reg [2:0] state,bit_index;
 reg [15:0] count;
 reg [7:0] shift;
 always @(posedge clk or posedge rst) begin
  if(rst) begin sync<=3;state<=0;count<=0;bit_index<=0;shift<=0;data<=0;valid<=0;framing_error<=0;end
  else begin
   sync<={sync[0],rx};valid<=0;framing_error<=0;
   case(state)
    0:if(!sync[1]) begin count<=DIV/2-1;state<=1;end
    1:if(count!=0) count<=count-1'b1;
      else if(sync[1]) state<=0;
      else begin state<=2;count<=DIV-1;bit_index<=0;end
    2:if(count!=0) count<=count-1'b1;
      else begin shift[bit_index]<=sync[1];count<=DIV-1;
       if(bit_index==7) state<=3;else bit_index<=bit_index+1'b1;end
    3:if(count!=0) count<=count-1'b1;
      else if(sync[1]) begin data<=shift;valid<=1;state<=0;end
      else begin framing_error<=1;state<=4;end
    4:if(sync[1]) state<=0;
    default:state<=0;
   endcase
  end
 end
endmodule

module uart_tx_byte #(parameter DIV=217)(input clk,rst,input [7:0] data,input valid,
 output tx,output busy);
 reg [9:0] shift;
 reg [3:0] left;
 reg [15:0] count;
 assign tx=shift[0];assign busy=(left!=0);
 always @(posedge clk or posedge rst) begin
  if(rst) begin shift<=10'h3ff;left<=0;count<=0;end
  else if(left!=0) begin
   if(count==0) begin shift<={1'b1,shift[9:1]};left<=left-1'b1;count<=DIV-1;end
   else count<=count-1'b1;
  end else if(valid) begin shift<={1'b1,data,1'b0};left<=10;count<=DIV-1;end
 end
endmodule
