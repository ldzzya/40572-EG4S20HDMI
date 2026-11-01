// Incremental catalogue: show the first image before scanning the remaining card.
// Named emergency assets require FAT32. Invalid filesystems fail closed;
// raw sector scanning would bypass filename separation and is not entered.
module sd_card_bmp #(
 parameter integer CLK_FREQ_HZ=25000000,parameter BUTTON_EVENTS=0,parameter OUT_W=640,OUT_H=480,
 parameter [31:0] SCAN_START_SECTOR=0,SCAN_MAX_SECTOR=131071,
 parameter [2:0] SCAN_TARGET_COUNT=4
)(
 input clk,rst,spi_clk,spi_rst,key_next,key_auto,
 output reg [3:0] state_code,
 input [15:0] bmp_width,bmp_height,
 output reg display_valid,commit_toggle,input commit_ack,
 output [15:0] source_width,source_height,input write_ready,
 input write_finish_toggle,
 output reg [1:0] write_buf_idx,disp_buf_idx,
 output write_req,input write_req_ack,output write_en,output [31:0] write_data,
 output SD_nCS,SD_DCLK,SD_MOSI,input SD_MISO,
 output [31:0] debug_sector,output reg [2:0] image_count,
 input aspect_fit,output reg auto_play_en,
 input image_swap,output wav_valid,output [23:0] wav_left,wav_right,output [3:0] wav_status,input priority_mode,output warning_ready,input playback_enable,output background_ready,input [1:0] active_frame_buf,input active_frame_valid,input [15:0] active_width,active_height,output [9:0] warning_top,output warning_format,output restore_cut,output [1:0] emergency_bank,held_frame,output hold_normal_frame
);
 localparam WAIT_INIT=0,SCAN_START=1,SCAN_WAIT=2,LOAD_START=3,LOAD_WAIT=4,
            PRESENT_WAIT=5,IDLE=6,FAILED=7;
 wire locked=priority_mode===1'b1;
 wire playing=locked || playback_enable!==1'b0;
 reg priority_seen,priority_pending;
 wire mounted,fat_ok;wire [2:0] fat_count;
 localparam [2:0] WARNING_SLOT=3'd4;
 wire priority_found;wire [2:0] priority_index;
 wire priority_available=fat_ok && priority_found;
 wire priority_request=locked && (priority_pending || !priority_seen);
 reg [3:0] state;
 // Logical buffer 2 aliases the unused physical bank; saved_buf is protected.
 reg priority_playing;
 reg session_active,saved_display,returning,restore_started,load_emergency;
 // A layout edit rebuilds the current picture, without restarting its WAV.
 // Latch each transaction's layout so menu changes cannot split one frame.
 reg shown_fit,loading_fit,saved_fit,format_reload;
 reg [2:0] saved_index;reg [1:0] saved_buf;reg [15:0] saved_width,saved_height;
 reg [$clog2(CLK_FREQ_HZ*5+1)-1:0] saved_auto;
 wire [15:0] decoded_width,decoded_height;
 wire checkpoint=locked && !priority_seen && !session_active;
 assign held_frame=session_active ? saved_buf : active_frame_buf;
 assign hold_normal_frame=locked && !priority_playing;
 assign emergency_bank=saved_display ? {1'b0,~saved_buf[0]} : 2'd0;
 wire audio_guard;
 assign background_ready=1'b0;
 assign restore_cut=session_active && !locked;
 assign source_width=returning ? saved_width : decoded_width;
 assign source_height=returning ? saved_height : decoded_height;
 reg load_start,next_pending;
 reg [31:0] load_sector;
 reg [$clog2(CLK_FREQ_HZ*5+1)-1:0] auto_count;
 reg [$clog2(CLK_FREQ_HZ*2+1)-1:0] commit_timer;
 
 reg [2:0] current_index,load_index;
 assign audio_guard=(locked && !priority_playing) ||
   (!locked && (current_index==WARNING_SLOT || (session_active && !restore_started)));
 reg [2:0] finish_sync,ack_sync;
 reg finish_seen,source_seen;
 wire ready,sd_init_done,scan_done,found,load_error;
 wire [31:0] found_sector,resume_sector;

 wire [3:0] reader_status;
 wire next_press,auto_press;
 wire read_sector,data_valid,sector_end;
 wire [31:0] sector_addr;
 wire [7:0] sector_data;
 wire fast_req,fast_valid,fast_end,fast_init;
 wire [31:0] fat_lba,data_lba,max_cluster,cat_bmp_cluster,cat_bmp_size,cat_wav_cluster,cat_wav_size;
 wire [2:0] cluster_shift;
 reg [31:0] bmp_cluster,bmp_file_size;
 wire [2:0] media_req,media_valid,media_done;wire [95:0] media_addr;wire [7:0] media_data;
 wire physical_req,physical_valid,physical_done;wire [31:0] physical_addr;wire [7:0] physical_data;
 wire [23:0] pcm_left,pcm_right;
 assign warning_ready=locked && priority_playing;
 assign wav_left=audio_guard ? 24'd0 : pcm_left;
 assign wav_right=audio_guard ? 24'd0 : pcm_right;
 wire wav_req,wav_byte_valid,wav_sector_done;wire [31:0] wav_addr,wav_cluster,wav_file_size;wire [7:0] wav_data;
 fat32_catalog catalogue_fs(.clk(clk),.rst(rst),.card_ready(sd_init_done),.index(load_index),
  .mounted(mounted),.fat_ok(fat_ok),.image_count(fat_count),.priority_found(priority_found),.priority_index(priority_index),
  .bmp_cluster(cat_bmp_cluster),.bmp_size(cat_bmp_size),.wav_cluster(cat_wav_cluster),.wav_size(cat_wav_size),
  .fat_lba(fat_lba),.data_lba(data_lba),.max_cluster(max_cluster),.cluster_shift(cluster_shift),
  .disk_req(media_req[0]),.disk_addr(media_addr[31:0]),.disk_data(media_data),.disk_valid(media_valid[0]),.disk_done(media_done[0]));
 fat_file_sector #(.PREFETCH_NEXT(1)) picture_file(.clk(clk),.rst(rst),.fat_mode(fat_ok),.fat_lba(fat_lba),.data_lba(data_lba),
  .max_cluster(max_cluster),.cluster_shift(cluster_shift),.first_cluster(bmp_cluster),.file_size(bmp_file_size),
  .req(read_sector),.sector(sector_addr),.data(sector_data),.valid(data_valid),.done(sector_end),
  .disk_req(media_req[1]),.disk_addr(media_addr[63:32]),.disk_data(media_data),.disk_valid(media_valid[1]),.disk_done(media_done[1]));
 fat_file_sector sound_file(.clk(clk),.rst(rst),.fat_mode(1'b1),.fat_lba(fat_lba),.data_lba(data_lba),
  .max_cluster(max_cluster),.cluster_shift(cluster_shift),.first_cluster(wav_cluster),.file_size(wav_file_size),
  .req(wav_req),.sector(wav_addr),.data(wav_data),.valid(wav_byte_valid),.done(wav_sector_done),
  .disk_req(media_req[2]),.disk_addr(media_addr[95:64]),.disk_data(media_data),.disk_valid(media_valid[2]),.disk_done(media_done[2]));
 wav_file_player #(.CLOCK_HZ(CLK_FREQ_HZ)) music(.checkpoint(checkpoint),.resume_saved(returning),.pause_playback(!playing || audio_guard || checkpoint),.clk(clk),.rst(rst),.start(image_swap && (!format_reload || returning)),
  .start_cluster(fat_ok ? cat_wav_cluster : 32'd0),.start_size(fat_ok ? cat_wav_size : 32'd0),
  .file_cluster(wav_cluster),.file_size(wav_file_size),.sector_req(wav_req),.sector_addr(wav_addr),
  .sector_data(wav_data),.sector_valid(wav_byte_valid),.sector_done(wav_sector_done),
  .pcm_valid(wav_valid),.pcm_left(pcm_left),.pcm_right(pcm_right),.status(wav_status),.buffered());
 media_sector_arbiter arbiter(.clk(clk),.rst(rst),.req(media_req),.addr(media_addr),
  .data(media_data),.valid(media_valid),.done(media_done),.sd_req(physical_req),.sd_addr(physical_addr),
  .sd_data(physical_data),.sd_valid(physical_valid),.sd_done(physical_done));
 wire [31:0] fast_addr;
 wire [7:0] fast_data;
 wire [23:0] bmp_data;wire [7:0] bmp_overlay;
 wire finish_pulse=finish_sync[2]^finish_sync[1];
 wire auto_due=playing && !locked && auto_play_en && !auto_press && image_count>1 && auto_count>=CLK_FREQ_HZ*5-1;
 wire [2:0] next_index=(current_index+3'd1<image_count) ? current_index+1'b1 : 2'd0;
 assign debug_sector=sector_addr;
 assign write_data={bmp_data,bmp_overlay};
 generate if(BUTTON_EVENTS) begin:button_events
  reg next_d,auto_d;
  always @(posedge clk or posedge rst)
   if(rst) begin next_d<=1;auto_d<=1;end else begin next_d<=key_next;auto_d<=key_auto;end
  assign next_press=next_d && !key_next;
  assign auto_press=auto_d && !key_auto;
 end else begin:physical_buttons
  key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) kn(clk,rst,key_next,next_press);
  key_press_debounce #(.CLK_FREQ_HZ(CLK_FREQ_HZ)) ka(clk,rst,key_auto,auto_press);
 end endgenerate
 always @* begin
  state_code=reader_status;
  if(!sd_init_done) state_code=0;
  else case(state)
   SCAN_START,SCAN_WAIT:state_code=2;
   LOAD_START,LOAD_WAIT:state_code=3;
   PRESENT_WAIT:state_code=4;
   IDLE:state_code=display_valid ? 1 : 15;
   FAILED:state_code=14;
  endcase
  if(locked && mounted && !priority_available) state_code=14;
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   shown_fit<=0;loading_fit<=0;saved_fit<=0;format_reload<=0;
   session_active<=0;saved_display<=0;returning<=0;restore_started<=0;load_emergency<=0;saved_index<=0;saved_buf<=0;saved_width<=0;saved_height<=0;saved_auto<=0;priority_seen<=0;priority_pending<=0;priority_playing<=0;
   bmp_cluster<=0;bmp_file_size<=0;state<=WAIT_INIT;load_start<=0;next_pending<=0;
   load_sector<=0;auto_count<=0;commit_timer<=0;
   current_index<=0;load_index<=0;finish_sync<=0;ack_sync<=0;
   finish_seen<=0;source_seen<=0;display_valid<=0;commit_toggle<=0;
   write_buf_idx<=0;disp_buf_idx<=0;image_count<=0;auto_play_en<=0;
  end else begin
   load_start<=0;
   finish_sync<={finish_sync[1:0],write_finish_toggle};ack_sync<={ack_sync[1:0],commit_ack};
   priority_seen<=locked;
   if(checkpoint) begin
    session_active<=1;saved_display<=(active_frame_valid===1'b1 || display_valid) && current_index!=WARNING_SLOT;
    saved_index<=image_swap ? load_index : current_index;
    saved_buf<=active_frame_valid===1'b1 ? active_frame_buf : disp_buf_idx;
    saved_width<=active_frame_valid===1'b1 ? active_width : decoded_width;
    saved_height<=active_frame_valid===1'b1 ? active_height : decoded_height;
    saved_auto<=auto_count;restore_started<=0;
    saved_fit<=image_swap ? loading_fit : shown_fit;
   end
   if(image_swap) begin
    current_index<=load_index;shown_fit<=returning ? saved_fit : loading_fit;
    if(returning) restore_started<=1;
   end
   if(!locked) begin priority_pending<=0;priority_playing<=0;end
   else begin
    next_pending<=0;
    if(!priority_seen) begin priority_pending<=1;priority_playing<=0;end
    if(image_swap) priority_playing<=priority_available && load_index==priority_index && load_emergency && !returning;
   end
   if(next_press && !locked && playing) next_pending<=1;
   if(auto_press && !locked) auto_play_en<=~auto_play_en;
   // Background searches must not restart the dwell timer.
   if(!playing) auto_count<=auto_count;
   else if(!locked && display_valid && auto_play_en && state!=LOAD_START && state!=LOAD_WAIT &&
      state!=PRESENT_WAIT && state!=FAILED) begin
    if(auto_count<CLK_FREQ_HZ*5-1) auto_count<=auto_count+1'b1;
   end else auto_count<=0;
   case(state)
    WAIT_INIT:if(sd_init_done && ready && mounted) begin
     if(fat_ok) begin
      image_count<=fat_count;load_index<=locked && priority_available ? priority_index : 2'd0;load_sector<=0;
      state<=fat_count!=0 || (locked && priority_available) ? LOAD_START : FAILED;
     end else begin state<=FAILED;end
    end
    LOAD_START:if(session_active && !locked) state<=IDLE;else if(playing) begin
     if(locked && priority_available && load_index!=priority_index) begin
      load_index<=priority_index;load_sector<=0;
     end else begin
     if(locked && priority_available) begin priority_pending<=0;write_buf_idx<=2;end
     load_emergency<=locked && priority_available;
     loading_fit<=aspect_fit;
     if(locked) format_reload<=0;
     if(fat_ok) begin bmp_cluster<=cat_bmp_cluster;bmp_file_size<=cat_bmp_size;end
     load_start<=1;finish_seen<=0;source_seen<=0;commit_timer<=0;state<=LOAD_WAIT;
     end
    end
    LOAD_WAIT:begin
     if(finish_pulse) finish_seen<=1;
     if(ready && !load_start) source_seen<=1;
     if(load_error) state<=FAILED;
     else if((finish_seen || finish_pulse) && source_seen) begin
      if(session_active && !locked) state<=IDLE;
      else if(locked && priority_available && !load_emergency) begin
       load_index<=priority_index;load_sector<=0;write_buf_idx<=2;state<=LOAD_START;
      end else begin
       if(locked && priority_available) priority_pending<=0;
       disp_buf_idx<=write_buf_idx;commit_toggle<=~commit_toggle;state<=PRESENT_WAIT;
      end
     end else if(source_seen) begin
      if(commit_timer>=CLK_FREQ_HZ*2-1) state<=FAILED;
      else commit_timer<=commit_timer+1'b1;
     end
    end
    PRESENT_WAIT:if(ack_sync[2]==commit_toggle) begin
     if(!(locked && !load_emergency)) begin display_valid<=1;current_index<=load_index;end
     state<=IDLE;
     if(returning) begin
      returning<=0;restore_started<=0;
      if(!locked) begin session_active<=0;auto_count<=saved_auto;end
     end
    end
    IDLE:begin
     if(session_active && !locked) begin
      next_pending<=0;
      if(saved_display) begin
       load_index<=saved_index;disp_buf_idx<=saved_buf;returning<=1;restore_started<=0;
       format_reload<=0;
       commit_toggle<=~commit_toggle;state<=PRESENT_WAIT;
      end else begin
       session_active<=0;display_valid<=0;load_index<=0;load_sector<=0;
       format_reload<=0;
       write_buf_idx<=0;state<=image_count!=0 ? LOAD_START : FAILED;
      end
     end else if(priority_request && priority_available) begin
      load_index<=priority_index;load_sector<=0;
      format_reload<=0;
      write_buf_idx<=2;
      next_pending<=0;auto_count<=0;state<=LOAD_START;
     end else if(!locked && playing && (next_pending || auto_due || !display_valid) && image_count!=0) begin
      load_index<=display_valid ? next_index : 2'd0;load_sector<=0;
      format_reload<=0;
      write_buf_idx<=display_valid ? {1'b0,~disp_buf_idx[0]} : 2'd0;
      next_pending<=0;auto_count<=0;state<=LOAD_START;
     end else if(!locked && playing && display_valid && aspect_fit!=shown_fit) begin
      load_index<=current_index;load_sector<=0;format_reload<=1;
      write_buf_idx<={1'b0,~disp_buf_idx[0]};state<=LOAD_START;
     end
    end
    FAILED:if(session_active && !locked) state<=IDLE;else if(priority_request && priority_available) begin
     load_index<=priority_index;load_sector<=0;priority_pending<=0;
     format_reload<=0;
     write_buf_idx<=2;state<=LOAD_START;
    end else if(next_press && !locked && playing) begin
     if(image_count!=0) begin load_sector<=0;load_index<=current_index;
      write_buf_idx<=display_valid ? {1'b0,~disp_buf_idx[0]} : 2'd0;state<=LOAD_START;
     end else if(!fat_ok) state<=FAILED;
     next_pending<=0;
    end
    default:state<=WAIT_INIT;
   endcase
  end
 end
 bmp_read #(.ENABLE_SCAN(0),.OUT_W(OUT_W),.OUT_H(OUT_H),.TIMEOUT_CYCLES(CLK_FREQ_HZ*2)) bmp_read_m0(.warning_top(warning_top),.warning_format(warning_format),
  .aspect_fit(loading_fit),.clk(clk),.rst(rst),.ready(ready),.scan_start(1'b0),.scan_start_sector(32'd0),
  .scan_max_sector(32'd0),.scan_target_count(3'd1),.scan_done(scan_done),
  .scan_found_valid(found),.scan_found_sector(found_sector),.scan_found_total(),.scan_resume_sector(resume_sector),
  .load_start(load_start),.load_sector(load_sector),.sd_init_done(sd_init_done),.state_code(reader_status),
  .bmp_width(bmp_width),.bmp_height(bmp_height),.source_width(decoded_width),.source_height(decoded_height),
  .load_error(load_error),.write_ready(write_ready),.write_req(write_req),.write_req_ack(write_req_ack),
  .sd_sec_read(read_sector),.sd_sec_read_addr(sector_addr),.sd_sec_read_data(sector_data),
  .sd_sec_read_data_valid(data_valid),.sd_sec_read_end(sector_end),.bmp_data_wr_en(write_en),.bmp_data(bmp_data),.bmp_overlay(bmp_overlay));
 sd_sector_bridge sector_bridge(
  .client_clk(clk),.client_rst(rst),.sd_clk(spi_clk),.sd_rst(spi_rst),
  .client_req(physical_req),.client_addr(physical_addr),.client_data(physical_data),
  .client_valid(physical_valid),.client_end(physical_done),.client_init_done(sd_init_done),
  .sd_req(fast_req),.sd_addr(fast_addr),.sd_data(fast_data),
  .sd_valid(fast_valid),.sd_end(fast_end),.sd_init_done(fast_init));
 sd_card_top #(.SPI_LOW_SPEED_DIV(248),.SPI_HIGH_SPEED_DIV(0)) sd_card_top_m0(
  .clk(spi_clk),.rst(spi_rst),.SD_nCS(SD_nCS),.SD_DCLK(SD_DCLK),.SD_MOSI(SD_MOSI),.SD_MISO(SD_MISO),
  .sd_init_done(fast_init),.sd_sec_read(fast_req),.sd_sec_read_addr(fast_addr),
  .sd_sec_read_data(fast_data),.sd_sec_read_data_valid(fast_valid),.sd_sec_read_end(fast_end),
  .sd_sec_write(1'b0),.sd_sec_write_addr(32'd0),.sd_sec_write_data(8'd0),
  .sd_sec_write_data_req(),.sd_sec_write_end());
endmodule

module key_press_debounce #(
    parameter integer CLK_FREQ_HZ = 100_000_000,
    parameter integer DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst,
    input  wire button_in,    // 默认：松开=1，按下=0
    output reg  press_pulse
);
localparam integer DEBOUNCE_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
reg button_sync0;
reg button_sync1;
reg button_stable;
reg [31:0] cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        button_sync0  <= 1'b1;
        button_sync1  <= 1'b1;
        button_stable <= 1'b1;
        cnt           <= 32'd0;
        press_pulse   <= 1'b0;
    end else begin
        button_sync0 <= button_in;
        button_sync1 <= button_sync0;
        press_pulse  <= 1'b0;
        if (button_sync1 == button_stable) begin
            cnt <= 32'd0;
        end else begin
            if (cnt >= DEBOUNCE_CYCLES - 1) begin
                if (button_stable && !button_sync1)
                    press_pulse <= 1'b1;
                button_stable <= button_sync1;
                cnt           <= 32'd0;
            end else begin
                cnt <= cnt + 32'd1;
            end
        end
    end
end
endmodule
