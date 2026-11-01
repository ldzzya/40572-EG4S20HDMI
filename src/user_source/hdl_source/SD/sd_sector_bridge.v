// One outstanding sector transaction, 25 MHz client <-> 100 MHz SD controller.
// Address/count are held stable across synchronized toggle handshakes. The RAM
// belongs to SD while filling, then to the client while replaying; no FIFO drops.
module sd_sector_bridge(
 input client_clk,client_rst,sd_clk,sd_rst,
 input client_req,input [31:0] client_addr,
 output reg [7:0] client_data,output reg client_valid,client_end,
 output client_init_done,
 output reg sd_req,output reg [31:0] sd_addr,
 input [7:0] sd_data,input sd_valid,sd_end,sd_init_done
);
 reg [7:0] sector_ram[0:511];
 reg [7:0] read_q;
 reg [31:0] address_mailbox;
 reg request_toggle,done_toggle,handled_toggle;
 reg [2:0] request_sync,done_sync,init_sync;
 reg [9:0] write_count,completed_count,replay_count,read_count;
 reg [8:0] read_index;
 reg sd_active;
 reg [2:0] state;
 localparam IDLE=0,WAIT_RESULT=1,PIPE=2,REPLAY=3,ENDING=4;
 assign client_init_done=init_sync[2];
 always @(posedge sd_clk) begin
  if(sd_active && sd_valid && write_count<512) sector_ram[write_count[8:0]]<=sd_data;
 end
 always @(posedge client_clk) read_q<=sector_ram[read_index];
 always @(posedge sd_clk or posedge sd_rst) begin
  if(sd_rst) begin
   request_sync<=0;handled_toggle<=0;done_toggle<=0;sd_active<=0;
   sd_req<=0;sd_addr<=0;write_count<=0;completed_count<=0;
  end else begin
   request_sync<={request_sync[1:0],request_toggle};
   if(!sd_active && sd_init_done && request_sync[2]!=handled_toggle) begin
    handled_toggle<=request_sync[2];sd_addr<=address_mailbox;
    write_count<=0;sd_req<=1;sd_active<=1;
   end
   if(sd_active && sd_valid) begin
    sd_req<=0;if(write_count<512) write_count<=write_count+1'b1;
   end
   if(sd_active && sd_end) begin
    sd_req<=0;sd_active<=0;done_toggle<=handled_toggle;
    completed_count<=write_count+((sd_valid && write_count<512) ? 10'd1 : 10'd0);
   end
  end
 end
 always @(posedge client_clk or posedge client_rst) begin
  if(client_rst) begin
   done_sync<=0;init_sync<=0;address_mailbox<=0;request_toggle<=0;
   replay_count<=0;read_count<=0;read_index<=0;state<=IDLE;
   client_data<=0;client_valid<=0;client_end<=0;
  end else begin
   done_sync<={done_sync[1:0],done_toggle};init_sync<={init_sync[1:0],sd_init_done};
   client_valid<=0;client_end<=0;
   case(state)
    IDLE:if(client_req && client_init_done) begin
     address_mailbox<=client_addr;request_toggle<=~request_toggle;state<=WAIT_RESULT;
    end
    WAIT_RESULT:if(done_sync[2]==request_toggle) begin
     replay_count<=completed_count;read_count<=0;read_index<=0;state<=PIPE;
    end
    PIPE:begin read_index<=1;state<=replay_count==0 ? ENDING : REPLAY;end
    REPLAY:begin
     client_data<=read_q;client_valid<=1;read_index<=read_index+1'b1;read_count<=read_count+1'b1;
     if(read_count+1'b1>=replay_count) state<=ENDING;
    end
    ENDING:begin client_end<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
