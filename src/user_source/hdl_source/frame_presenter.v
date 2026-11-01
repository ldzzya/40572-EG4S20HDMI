module frame_presenter #(parameter FADE_STEP=8)(
 input clk,rst,frame_tick,request_toggle,
 input [1:0] requested_buf,
 input [15:0] source_width,source_height,
 output reg ack_toggle, output reg [1:0] active_buf,
 output reg display_active, output reg [5:0] gain,
 output reg [15:0] shown_width,shown_height,
 output reg image_swap,input [1:0] transition,input pause_playback,input emergency_hold
);
 reg [2:0] req_sync;
 reg pending,token;
 reg [1:0] target_buf;
 reg [15:0] target_w,target_h;
 reg [1:0] state;
 reg cut_pending;
 localparam IDLE=0,DOWN=1,SWITCH=2,UP=3;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   image_swap<=0;req_sync<=0; pending<=0; token<=0; target_buf<=0; target_w<=0; target_h<=0;
   ack_toggle<=0; active_buf<=0; display_active<=0; gain<=0; state<=IDLE;
   shown_width<=0; shown_height<=0;cut_pending<=0;
  end else begin
   image_swap<=0;req_sync<={req_sync[1:0],request_toggle};
   if(!pending && req_sync[2]!=ack_toggle) begin
    pending<=1; token<=req_sync[2]; target_buf<=requested_buf;
    target_w<=source_width; target_h<=source_height;cut_pending<=transition===2'd2;
   end
   // Priority mode uses cut and can finish an already-running transition.
   if(frame_tick && pending && emergency_hold===1'b1 && target_buf!=2) begin
    // Finish a pre-alarm normal request without exposing its back buffer.
    // The SD controller may now reuse that buffer for the warning image.
    ack_toggle<=token;pending<=0;state<=IDLE;gain<=display_active ? 32 : 0;
   end else if(frame_tick && transition===2'd2 && pending) begin
    image_swap<=1;active_buf<=target_buf;shown_width<=target_w;shown_height<=target_h;
    display_active<=1;gain<=32;ack_toggle<=token;pending<=0;state<=IDLE;
   end else if(frame_tick && pause_playback!==1'b1) case(state)
    IDLE: if(pending) begin
     if(display_active && !cut_pending) state<=DOWN;
     else begin
      image_swap<=1;active_buf<=target_buf;shown_width<=target_w;shown_height<=target_h;
      display_active<=1;gain<=32;ack_toggle<=token;pending<=0;
     end
    end
    DOWN: if(gain>FADE_STEP) gain<=gain-FADE_STEP;
          else begin gain<=0;state<=SWITCH;end
    SWITCH: begin
     image_swap<=1;active_buf<=target_buf; shown_width<=target_w; shown_height<=target_h;
     display_active<=1; gain<=0; state<=UP;
    end
    UP: if(gain+FADE_STEP<32) gain<=gain+FADE_STEP;
        else begin gain<=32;ack_toggle<=token;pending<=0;state<=IDLE;end
   endcase
  end
 end
endmodule
module reset_release(input clk,arst,output rst);
 reg [2:0] pipe;
 always @(posedge clk or posedge arst)
  if(arst) pipe<=3'b111; else pipe<={pipe[1:0],1'b0};
 assign rst=pipe[2];
endmodule
