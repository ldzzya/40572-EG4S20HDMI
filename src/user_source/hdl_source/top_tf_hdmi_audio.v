`default_nettype none

module top(
    input wire                       clk,
    input wire                       rst_n,
    input wire                       uart_rx,
    output wire                      uart_tx,
    input wire                       key1,           // 手动下一张
    input wire [3:0]                 sw,
    input wire                       key3,
    input wire                       key2,           // 自动播放 开/关
    output wire [5:0]                seg_sel,
    output wire [7:0]                seg_data,
    // HDMI TMDS
    output wire                      HDMI_CLK_P,
    output wire                      HDMI_D2_P,
    output wire                      HDMI_D1_P,
    output wire                      HDMI_D0_P,
    // HDMI DDC
    output wire                      HDMI_DDC_SCL,
    inout wire                       HDMI_DDC_SDA,
    // TF card SPI
    output wire                      sd_ncs,
    output wire                      sd_dclk,
    output wire                      sd_mosi,
    input wire                       sd_miso
);
// Declare shared controls before every use: TD 6.2 otherwise drops a
// declaration assignment after an implicit instance-port declaration.
wire video_clk,rst_video,display_active,frame_tick;
wire playback_requested,media_playing;
// SW1/C8 is the sole functional switch. SW2--SW4 are intentionally unused.
wire priority_50,reset_button_n;wire [3:0] allowed_keys;
priority_guard priority_input(.clk(clk),.switch_1(sw[0]),
 .buttons_n({key2,key3,key1,rst_n}),.locked(priority_50),.allowed_buttons_n(allowed_keys));
assign reset_button_n=allowed_keys[0];
reg [1:0] priority_sync;
wire priority_mode=priority_sync[1];
assign media_playing=priority_mode || playback_requested;
always @(posedge video_clk or posedge rst_video)
 if(rst_video) priority_sync<=0;else priority_sync<={priority_sync[0],priority_50};
parameter MEM_DATA_BITS = 32;
parameter ADDR_BITS     = 21;
parameter BUSRT_BITS    = 10;
parameter FRAME_WORDS = 21'd691200; // 1280*720*24/32; no RGB quantization   // 1280*720, RGB24 + independent overlay byte
parameter BUF0_ADDR     = 21'd0;
parameter BUF1_ADDR     = FRAME_WORDS;
// Three full RGB24 frames occupy 8,294,400 bytes of the 8 MiB SDRAM.
parameter EMERGENCY_ADDR=FRAME_WORDS*2;
wire [1:0] emergency_bank,held_frame;
wire hold_normal_frame;
wire video_reference;
localparam VIDEO_HZ=74250000;
wire Sdr_init_done;
wire Sdr_init_ref_vld;
wire Sdr_busy;
wire sd_card_clk;
wire spi_clk,rst_spi;
wire ext_mem_clk;
wire ext_mem_clk_sft;

assign sd_card_clk=video_clk;
wire hdmi_5x_clk;
wire hs;
wire vs;
wire de;
wire [23:0] vout_data_raw;
wire [9:0] warning_top;wire warning_format;
wire layer_vs,layer_de;wire [23:0] layer_rgb;wire [7:0] warning_pixel;
wire warning_ready,restore_cut;
wire [23:0] vout_data;
wire        display_valid;
wire media_image_ready;
wire [3:0]  state_code;
wire [6:0]  seg_data_0;
wire [6:0] seg_hdmi,seg_pll;
wire hdmi_video_locked;
reg [1:0] hdmi_lock_sync;
wire        video_read_req;
wire        video_read_req_ack;
wire        video_read_en;
wire [23:0] video_read_data;
wire        sd_card_write_en;
wire [31:0] sd_card_write_data;
wire        sd_card_write_req;
wire        sd_card_write_req_ack;
wire        frame_write_finish;
reg         frame_write_toggle_mem;
wire [1:0]  write_buf_idx;
wire [1:0]  disp_buf_idx;
wire App_rd_en;
wire [ADDR_BITS-1:0] App_rd_addr;
wire Sdr_rd_en;
wire [MEM_DATA_BITS-1:0] Sdr_rd_dout;
wire App_wr_en;
wire [ADDR_BITS-1:0] App_wr_addr;
wire [MEM_DATA_BITS-1:0] App_wr_din;
wire [3:0] App_wr_dm;
wire hs_0;
wire vs_0;
wire de_0;
// HDMI 1.4b 音频发射相关
wire        audio_valid;
wire wav_valid,image_swap;wire [3:0] wav_status;
wire [23:0] wav_left,wav_right;
wire next_short_n,auto_short_n,volume_down,volume_up;
wire [4:0] volume_level;
wire [6:0] subtitle_addr;
wire [7:0] subtitle_char;
wire subtitle_active,subtitle_changed;
wire [3:0] subtitle_updates;
wire [23:0] audio_left_data;
wire [23:0] audio_right_data;
wire        acr_valid;
wire [19:0] acr_cts;
wire [19:0] acr_n;
wire        axis_s_user;
wire        axis_s_valid;
wire        axis_s_last;
wire [23:0] axis_s_data;
wire        axis_s_ready;
wire        edid_trig;
wire        edid_valid;
wire [7:0]  edid_data;
wire [9:0]  tmds_ch0_data;
wire [9:0]  tmds_ch1_data;
wire [9:0]  tmds_ch2_data;
wire [9:0]  tmds_clk_data;
// 统一复位：TF 图像链路 + HDMI 音频链路
wire rst_all;
wire sys_lock,video_lock;
wire rst_sd,rst_mem;
reg [1:0] read_ack_video;
always @(posedge video_clk or posedge rst_video)
 if(rst_video) read_ack_video<=0;else read_ack_video<={read_ack_video[0],video_read_req_ack};
reg [3:0] sd_status_meta,sd_status_50;
always @(posedge clk or negedge reset_button_n)
 if(!reset_button_n) begin sd_status_meta<=0;sd_status_50<=0;end
 else begin sd_status_meta<=state_code;sd_status_50<=sd_status_meta;end
reg [2:0] lock_sync;
// 2^20 / 50 MHz = 20.97 ms stable release; preserve the baseline reset topology.
reg [20:0] por_count;
wire locks_ok=sys_lock & video_lock;
always @(posedge clk or negedge reset_button_n)
 if(!reset_button_n) lock_sync<=0; else lock_sync<={lock_sync[1:0],locks_ok};
always @(posedge clk or negedge reset_button_n)
 if(!reset_button_n) por_count<=0;
 else if(!lock_sync[2]) por_count<=0;
 else if(!por_count[20]) por_count<=por_count+1'b1;
assign rst_all=~reset_button_n | ~locks_ok | ~por_count[20];
reset_release rspi(spi_clk,rst_all,rst_spi);
reset_release rsd(sd_card_clk,rst_all,rst_sd);
reset_release rmem(ext_mem_clk,rst_all,rst_mem);
reset_release rv(video_clk,rst_all,rst_video);
wire commit_toggle,commit_ack,write_ready;
wire [15:0] source_width,source_height,shown_width,shown_height;
wire [1:0] active_buf;
wire [5:0] fade_gain;
wire ui_english,aspect_fit;wire [1:0] transition;
wire [31:0] debug_sector;
wire [2:0] image_count;
wire auto_play_en;
wire fx_vs,fx_de;
wire [23:0] fx_rgb;
reg req_d;
reg [7:0] read_request_delay;
assign frame_tick=video_read_req & ~req_d;
// UI and UART commit follow the actual video sync, even if SDRAM has not
// acknowledged a read request. The framebuffer presenter keeps its original
// request-bound swap timing below.
reg ui_vs_d;
wire ui_frame_tick=vs && !ui_vs_d;
always @(posedge video_clk or posedge rst_video)
 if(rst_video) ui_vs_d<=0;else ui_vs_d<=vs;
always @(posedge video_clk or posedge rst_video)
 if(rst_video) begin req_d<=0;read_request_delay<=0;end
 else begin req_d<=video_read_req;read_request_delay<={read_request_delay[6:0],video_read_req};end
frame_presenter #(.FADE_STEP(2)) presenter(.emergency_hold(hold_normal_frame),.pause_playback(!media_playing),.image_swap(image_swap),.clk(video_clk),.rst(rst_video),.frame_tick(frame_tick),
 .request_toggle(commit_toggle),.requested_buf(hold_normal_frame && disp_buf_idx!=2 ? held_frame : disp_buf_idx),
 .source_width(source_width),.source_height(source_height),.ack_toggle(commit_ack),
 .active_buf(active_buf),.display_active(display_active),.gain(fade_gain),
 .shown_width(shown_width),.shown_height(shown_height),.transition((priority_mode || restore_cut) ? 2'd2 : transition));
reg [3:0] status_meta,status_sync;
always @(posedge video_clk) begin status_meta<=state_code;status_sync<=status_meta;end
wire [2:0] ui_page,ui_selection;

wire ui_field,mode_short_n,muted,caption_pause,caption_visible;
wire [1:0] caption_speed;
wire [3:0] display_settings;
menu_controller #(.CLK_HZ(VIDEO_HZ)) controls(.playback_requested(playback_requested),.clk(video_clk),.rst(rst_video),.frame_tick(ui_frame_tick),
 .prev_n(allowed_keys[1]),.ok_n(allowed_keys[2]),.next_n(allowed_keys[3]),.switches(4'd0),.priority_mode(priority_mode),
 .ui_page(ui_page),.ui_selection(ui_selection),.ui_field(ui_field),
 .display_settings(display_settings),.next_image_n(next_short_n),.auto_play_n(auto_short_n),
 .mode_n(mode_short_n),.volume_down(volume_down),.volume_up(volume_up),.muted(muted),
 .caption_pause(caption_pause),.caption_visible(caption_visible),.caption_speed(caption_speed),.english(ui_english),.aspect_fit(aspect_fit),.transition(transition));
subtitle_uart #(.CLOCK_HZ(VIDEO_HZ)) captions(.clk(video_clk),.rst(rst_video),.rx(uart_rx),.tx(uart_tx),
 .frame_tick(ui_frame_tick),.text_addr(subtitle_addr),.text_char(subtitle_char),
 .custom_active(subtitle_active),.text_changed(subtitle_changed),.update_count(subtitle_updates));
video_effects #(.ENABLE_MENU(1),.BUTTON_EVENTS(1),.WIDTH(1280),.HEIGHT(720),.CLOCK_HZ(VIDEO_HZ),.FRAME_HZ(60)) effects(.warning_pixel(warning_pixel),.warning_ready(warning_ready),.clk(video_clk),.rst(rst_video),.priority_mode(priority_mode),.frame_tick(ui_frame_tick),
 .vs(layer_vs),.de(layer_de),.rgb(layer_rgb),.gain(fade_gain),.switches(display_settings),.mode_key(mode_short_n),
 .source_width(shown_width),.source_height(shown_height),.status(status_sync),
 .image_ready(media_image_ready),.scan_sector(debug_sector),.image_count(image_count),.autoplay(auto_play_en && !priority_mode),
 .audio_status(wav_status),.audio_valid(audio_valid),.audio_left(audio_left_data),.audio_right(audio_right_data),
 .ui_page(priority_mode ? 3'd1 : ui_page),.ui_selection(ui_selection),.ui_field(ui_field),.muted(muted),
 .caption_pause(caption_pause),.caption_visible(caption_visible),.caption_speed(caption_speed),
 .english(ui_english),.aspect_fit(aspect_fit),.transition(priority_mode ? 2'd2 : transition),.subtitle_updates(subtitle_updates),.volume_level(volume_level),.subtitle_active(subtitle_active),.subtitle_char(subtitle_char),
 .subtitle_changed(subtitle_changed),.subtitle_addr(subtitle_addr),
 .out_vs(fx_vs),.out_de(fx_de),.out_rgb(fx_rgb));
// 99 MHz SD protocol (24.75 MHz SPI), 74.25 MHz video (720p60), 49.5 MHz SDRAM.
sys_pll sys_pll_m0(
    .extlock(sys_lock),
    .refclk     (clk),
    .clk0_out   (spi_clk),
    .clk1_out   (ext_mem_clk),
    .clk2_out   (ext_mem_clk_sft),
    .clk3_out(video_reference),
    .reset      (1'b0)
);
video_pll video_pll_m0(
    .extlock(video_lock),
    .refclk     (video_reference),
    .clk0_out   (video_clk),
    .clk1_out   (hdmi_5x_clk),
    .reset      (1'b0)
);
// Audio uses a 48 kHz clock enable in the video clock domain.
// mem_clk 域把 write_finish 单拍转成 toggle，供 sd_card_clk 域可靠同步
always @(posedge ext_mem_clk or posedge rst_mem) begin
    if (rst_mem)
        frame_write_toggle_mem <= 1'b0;
    else if (frame_write_finish)
        frame_write_toggle_mem <= ~frame_write_toggle_mem;
end
// ===================== TF 多图扫描与缓存（双缓冲） =====================
sd_card_bmp #(
    .CLK_FREQ_HZ       (VIDEO_HZ),.OUT_W(1280),.OUT_H(720),
    .BUTTON_EVENTS(1),
    .SCAN_START_SECTOR (32'd0),
    .SCAN_MAX_SECTOR   (32'd131071),
    .SCAN_TARGET_COUNT (3'd4)
) sd_card_bmp_m0(.warning_top(warning_top),.warning_format(warning_format),.emergency_bank(emergency_bank),.held_frame(held_frame),.hold_normal_frame(hold_normal_frame),.active_frame_buf(active_buf),.active_frame_valid(display_active),.active_width(shown_width),.active_height(shown_height),.restore_cut(restore_cut),.playback_enable(playback_requested),.warning_ready(warning_ready),.priority_mode(priority_mode),.image_swap(image_swap),.wav_valid(wav_valid),.wav_left(wav_left),.wav_right(wav_right),.wav_status(wav_status),
    .clk               (sd_card_clk),
    .spi_clk(spi_clk),.spi_rst(rst_spi),
    .rst               (rst_sd),
    .key_next          (next_short_n),
    .key_auto          (auto_short_n),
    .state_code        (state_code),
    .debug_sector(debug_sector),.image_count(image_count),.auto_play_en(auto_play_en),
    .aspect_fit(aspect_fit),
    .bmp_width         (16'd1280),
    .bmp_height        (16'd720),
    .display_valid     (display_valid),
    .commit_toggle(commit_toggle),.commit_ack(commit_ack),
    .source_width(source_width),.source_height(source_height),.write_ready(write_ready),
    .write_finish_toggle(frame_write_toggle_mem),
    .write_buf_idx     (write_buf_idx),
    .disp_buf_idx      (disp_buf_idx),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data),
    .SD_nCS            (sd_ncs),
    .SD_DCLK           (sd_dclk),
    .SD_MOSI           (sd_mosi),
    .SD_MISO           (sd_miso)
);
// Stable startup result, synchronized only for the spare diagnostic digit.
wire [3:0] mem_align_status;
wire [7:0] mem_align_detail;
reg [11:0] align_meta,align_sync;
wire [6:0] seg_align,seg_align_high,seg_align_low;
always @(posedge clk or negedge reset_button_n)
 if(!reset_button_n)begin align_meta<=12'h00c;align_sync<=12'h00c;end
 else begin align_meta<={mem_align_detail,mem_align_status};align_sync<=align_meta;end
seg_decoder align_decoder(.bin_data(align_sync[3:0]),.seg_data(seg_align));
seg_decoder align_high_decoder(.bin_data(align_sync[11:8]),.seg_data(seg_align_high));
seg_decoder align_low_decoder(.bin_data(align_sync[7:4]),.seg_data(seg_align_low));
seg_decoder seg_decoder_m0(
    .bin_data          (sd_status_50),
    .seg_data          (seg_data_0)
);
// Keep the rightmost SD state digit; expose HDMI/PLL lock on its left.
always @(posedge clk or negedge reset_button_n)
 if(!reset_button_n) hdmi_lock_sync<=0;
 else hdmi_lock_sync<={hdmi_lock_sync[0],hdmi_video_locked};
seg_decoder hdmi_status_decoder(.bin_data({3'b0,hdmi_lock_sync[1]}),.seg_data(seg_hdmi));
seg_decoder pll_status_decoder(.bin_data({3'b0,lock_sync[2]}),.seg_data(seg_pll));
seg_scan seg_scan_m0(
    .clk               (clk),
    .rst_n             (reset_button_n),
    .seg_sel           (seg_sel),
    .seg_data          (seg_data),
    .seg_data_0        ({1'b1,seg_align_high}),
    .seg_data_1        ({1'b1,seg_align_low}),
    .seg_data_2        ({1'b1,seg_align}),
    .seg_data_3        ({1'b1,seg_pll}),
    .seg_data_4        ({1'b1,seg_hdmi}),
    .seg_data_5        ({1'b1,seg_data_0})
);
// ===================== 原图像时序与帧缓存 =====================
video_timing_data video_timing_data_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_req          (video_read_req),
    .read_req_ack      (read_ack_video[1]),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0)
);
video_delay #(.DATA_WIDTH(24)) video_delay_m0(
    .video_clk         (video_clk),
    .rst               (rst_video),
    .read_en           (video_read_en),
    .read_data         (video_read_data),
    .hs                (hs_0),
    .vs                (vs_0),
    .de                (de_0),
    .hs_r              (hs),
    .vs_r              (vs),
    .de_r              (de),
    .vout_data         (vout_data_raw)
);
// Use the validity of the selected buffer, including the independent home image.
// An emergency-only card has no ordinary image to restore after SW1 exits.
assign media_image_ready=display_active && display_valid && (priority_mode || active_buf!=2 || image_count!=0);
assign vout_data = media_image_ready ? vout_data_raw : 24'd0;
// Only the warning mask is reduced to a compact 640x40 cache. The BMP
// background remains native 1280x720 RGB24. Both read paths align by one clock.
warning_layer_cache warning_layer(.clk(video_clk),.rst(rst_video),
 .load_reset(sd_card_write_req),.load_enable(write_buf_idx==2 && warning_format),
 .write_en(sd_card_write_en),.write_mask(sd_card_write_data[7:0]),.strip_top(warning_top),
 .show(warning_ready && warning_format),.vs(vs),.de(de),.rgb(vout_data),
 .out_vs(layer_vs),.out_de(layer_de),.out_rgb(layer_rgb),.mask(warning_pixel));
frame_read_write #(
    .READ_DATA_BITS(24),.WRITE_DATA_BITS(24),
    .WRITE_V_FLIP     (1),
    .FRAME_WIDTH      (960),
    .FRAME_HEIGHT     (720)
) frame_read_write_m0(
    .mem_clk           (ext_mem_clk),
    .rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout),
    .read_clk          (video_clk),
    .read_req          (read_request_delay[7]),
    .read_req_ack      (video_read_req_ack),
    .read_finish       (),
    .read_addr_0       (BUF0_ADDR),
    .read_addr_1       (BUF1_ADDR),
    .read_addr_2       (EMERGENCY_ADDR),
    .read_addr_3       (21'd0),
    .read_addr_index   (active_buf),
    .read_len          (FRAME_WORDS),
    .read_en           (video_read_en),
    .read_data         (video_read_data),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_din        (App_wr_din),
    .App_wr_dm         (App_wr_dm),
    .write_clk         (sd_card_clk),
    .write_req         (sd_card_write_req),
    .write_req_ack     (sd_card_write_req_ack),
    .write_finish      (frame_write_finish),
    .write_addr_0      (BUF0_ADDR),
    .write_addr_1      (BUF1_ADDR),
    .write_addr_2      (EMERGENCY_ADDR),
    .write_addr_3      (21'd0),
    .write_addr_index  (write_buf_idx),
    .write_len         (FRAME_WORDS),
    .write_ready(write_ready),
    .write_en          (sd_card_write_en),
    .write_data        (sd_card_write_data[31:8])
);
sdram U3(
    .align_status(mem_align_status),
    .align_detail(mem_align_detail),
    .Clk               (ext_mem_clk),
    .Clk_sft           (ext_mem_clk_sft),
    .Rst               (rst_mem),
    .Sdr_init_done     (Sdr_init_done),
    .Sdr_init_ref_vld  (Sdr_init_ref_vld),
    .Sdr_busy          (Sdr_busy),
    .App_wr_en         (App_wr_en),
    .App_wr_addr       (App_wr_addr),
    .App_wr_dm         (App_wr_dm),
    .App_wr_din        (App_wr_din),
    .App_rd_en         (App_rd_en),
    .App_rd_addr       (App_rd_addr),
    .Sdr_rd_en         (Sdr_rd_en),
    .Sdr_rd_dout       (Sdr_rd_dout)
);
// ===================== TF WAV: fixed 48 kHz PCM output =====================
audio_volume volume(.clk(video_clk),.rst(rst_video),.down(volume_down && !priority_mode),.up(volume_up && !priority_mode),
 .in_valid(wav_valid),.in_left(wav_left),.in_right(wav_right),.out_valid(audio_valid),
 .out_left(audio_left_data),.out_right(audio_right_data),.level(volume_level),.mute(muted));
audio_arc_calculate #(
    .ACR_N         (6144)
) u_audio_arc_calculate (
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_audio_valid (audio_valid),
    .O_acr_valid   (acr_valid),
    .O_acr_cts     (acr_cts),
    .O_acr_n       (acr_n)
);
// ===================== RGB/DE 转 AXIS 视频 =====================
video_rgb_to_axis_640x480 #(.WIDTH(1280)) u_video_rgb_to_axis_640x480(
    .I_clk         (video_clk),
    .I_rst         (rst_video),
    .I_vs          (fx_vs),
    .I_de          (fx_de),
    .I_rgb         (fx_rgb),
    .O_video_user  (axis_s_user),
    .O_video_valid (axis_s_valid),
    .O_video_last  (axis_s_last),
    .O_video_data  (axis_s_data)
);
// 上电后自动打一拍，触发一次 EDID 读取
startup_pulse #(
    .CNT_MAX(20'd100000)
) u_startup_pulse (
    .I_clk   (video_clk),
    .I_rst   (rst_video),
    .O_pulse (edid_trig)
);
// ===================== 带音频的 HDMI 1.4b 发射 =====================
hdmi_1_4b_transmitter_core_wrapper #(
    .DEVICE                 ( "EG"       ),
    .HTOTAL                 ( 1650 ),
    .HSA                    ( 40 ),
    .HFP                    ( 110 ),
    .HBP                    ( 220 ),
    .HACTIVE                ( 1280 ),
    .VTOTAL                 ( 750 ),
    .VSA                    ( 5 ),
    .VFP                    ( 5 ),
    .VBP                    ( 20 ),
    .VACTIVE                ( 720 ),
    .VIDEO_VIC              ( 4 ),
    .VIDEO_TPG              ( "Disable"  ),
    .VIDEO_FORMAT           ( "RGB"      ),
    .AUDIO_SAMPLE_RATE      ( "48K"      ),
    .IIC_SCL_DIV            ( 743 )
) u_hdmi_1_4b_transmitter_core_wrapper(
    .I_pixel_clk        (video_clk),
    .I_rst              (rst_video),
    .I_edid_read_trig   (edid_trig),
    .O_edid_read_valid  (edid_valid),
    .O_edid_read_data   (edid_data),
    .I_axis_s_user      (axis_s_user),
    .I_axis_s_valid     (axis_s_valid),
    .I_axis_s_last      (axis_s_last),
    .I_axis_s_data      (axis_s_data),
    .O_axis_s_ready     (axis_s_ready),
    .I_audio_valid      (audio_valid),
    .I_audio_left_data  (audio_left_data),
    .I_audio_right_data (audio_right_data),
    .I_acr_valid        (acr_valid),
    .I_acr_cts          (acr_cts),
    .I_acr_n            (acr_n),
    .O_video_locked     (hdmi_video_locked),
    .O_ddc_scl          (HDMI_DDC_SCL),
    .IO_ddc_sda         (HDMI_DDC_SDA),
    .O_ch0_tmds_data    (tmds_ch0_data),
    .O_ch1_tmds_data    (tmds_ch1_data),
    .O_ch2_tmds_data    (tmds_ch2_data),
    .O_clk_tmds_data    (tmds_clk_data)
);
hdmi_phy_wrapper #(
    .DEVICE ( "EG" )
) u_hdmi2phy_wrapper(
    .I_pixel_clk        (video_clk),
    .I_serial_clk       (hdmi_5x_clk),
    .I_rst              (rst_video),
    .I_tmds_channel_0   (tmds_ch0_data),
    .I_tmds_channel_1   (tmds_ch1_data),
    .I_tmds_channel_2   (tmds_ch2_data),
    .I_tmds_channel_clk (tmds_clk_data),
    .O_tmds_ch0_p       (HDMI_D0_P),
    .O_tmds_ch1_p       (HDMI_D1_P),
    .O_tmds_ch2_p       (HDMI_D2_P),
    .O_tmds_clk_p       (HDMI_CLK_P)
);
endmodule

`default_nettype wire
