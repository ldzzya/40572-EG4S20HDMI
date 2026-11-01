// RIFF chunk walker and PCM decoder. Sector service may stall arbitrarily.
// All addresses are relative to the selected file; FAT mapping is external.
// Missing/unsupported/truncated audio is silence and never blocks the picture.
module wav_file_player #(parameter CLOCK_HZ=25000000)(
 input clk,rst,start,input [31:0] start_cluster,start_size,
 output reg [31:0] file_cluster,file_size,
 output reg sector_req,output reg [31:0] sector_addr,
 input [7:0] sector_data,input sector_valid,sector_done,
 output pcm_valid,output [23:0] pcm_left,pcm_right,
 output reg [3:0] status,output [10:0] buffered,input pause_playback,input checkpoint,resume_saved
);
 localparam IDLE=0,GET=1,CACHE_WAIT=2,PIPE=3,USE=4,HEADER_CHECK=5,
 CHUNK_CHECK=6,FMT_CHECK=7,FAIL=8,RESTART=9,CHUNK_PREP=10;
 reg [3:0] state;reg [1:0] phase;
 reg [31:0] position,cache_sector,chunk_id,chunk_len,chunk_end,riff_end,data_start,data_end;
 reg [31:0] last_data_byte;
 // Stable throughout GET/PIPE/USE; removes a 32-bit increment from USE's
 // loop-wrap decision while preserving the exact byte and PCM checkpoint.
 always @(posedge clk)last_data_byte<=data_end-1'b1;
 reg [31:0] riff_size;reg riff_ok,wave_ok;reg [1:0] chunk_mod3;
 reg [15:0] format;reg [1:0] channels;reg [7:0] bits,valid_bits;reg [2:0] align;
 reg fields_ok,subtype_ok;reg [1:0] rate_match;
 reg [5:0] field;reg [7:0] guid_byte;
 always @* case(field)
  24:guid_byte=8'h01;30:guid_byte=8'h10;32:guid_byte=8'h80;
  35:guid_byte=8'haa;37:guid_byte=8'h38;38:guid_byte=8'h9b;39:guid_byte=8'h71;
  default:guid_byte=0;
 endcase
 
 reg [9:0] received;reg cache_valid,fmt_ok,enabled,rate_44100;
 reg pending;reg [31:0] pending_cluster,pending_size;
 reg [7:0] cache[0:511];reg [7:0] q;
 reg [2:0] sample_byte;reg [23:0] sample_l,sample_r;
 reg push,flush;reg restore_pcm,pending_resume,resume_active;
 reg restore_inflight;reg saved_valid;reg [31:0] saved_cluster,saved_size,saved_position,consume_position;
 wire sample_taken;wire room,underrun;
 reg [32:0] chunk_limit;
 wire data_aligned=align==2 ? !chunk_len[0] : align==4 ? chunk_len[1:0]==0 :
                   align==3 ? chunk_mod3==0 : align==6 ? chunk_mod3==0 && !chunk_len[0] : 1'b0;
 wire [4:0] mod_digits={3'b0,q[1:0]}+{3'b0,q[3:2]}+{3'b0,q[5:4]}+{3'b0,q[7:6]}+(field==4 ? 5'd0 : {3'b0,chunk_mod3});
 wire [23:0] assembled=bits==16 ? {q,sample_l[15:8],8'b0} : {q,sample_l[15:0]};
 wire [23:0] assembled_r=bits==16 ? {q,sample_r[15:8],8'b0} : {q,sample_r[15:0]};
 wav_pcm_48k #(.CLOCK_HZ(CLOCK_HZ)) output_pcm(.checkpoint(checkpoint===1'b1 && !restore_inflight),.restore_context(restore_pcm),.sample_taken(sample_taken),.pause_playback(pause_playback),.clk(clk),.rst(rst),.flush(flush || start),.enable(enabled && !pending),
  .rate_44100(rate_44100),.push(push),.in_left(sample_l),.in_right(sample_r),.room(room),
  .valid(pcm_valid),.left(pcm_left),.right(pcm_right),.underrun(underrun),.buffered(buffered));
 always @(posedge clk) begin
  if(state==CACHE_WAIT && sector_valid) cache[received[8:0]]<=sector_data;
  q<=cache[position[8:0]];
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   restore_inflight<=0;saved_valid<=0;saved_cluster<=0;saved_size<=0;saved_position<=0;consume_position<=0;restore_pcm<=0;pending_resume<=0;resume_active<=0;
   state<=IDLE;phase<=0;position<=0;chunk_limit<=0;cache_sector<=0;chunk_id<=0;chunk_len<=0;chunk_end<=0;
   riff_end<=0;data_start<=0;data_end<=0;riff_ok<=1;wave_ok<=1;chunk_mod3<=0;riff_size<=0;rate_match<=0;fields_ok<=1;subtype_ok<=1;
   format<=0;channels<=0;bits<=0;align<=0;valid_bits<=0;field<=0;received<=0;cache_valid<=0;fmt_ok<=0;
   enabled<=0;rate_44100<=0;pending<=0;pending_cluster<=0;pending_size<=0;
   sample_byte<=0;sample_l<=0;sample_r<=0;push<=0;flush<=0;
   file_cluster<=0;file_size<=0;sector_req<=0;sector_addr<=0;status<=0;
  end else begin
   push<=0;flush<=0;restore_pcm<=0;
   if(sample_taken && phase==3) consume_position<=consume_position+align>=data_end ? data_start : consume_position+align;
   if(sample_taken) restore_inflight<=0;
   if(checkpoint===1'b1 && !restore_inflight) begin
    saved_valid<=enabled && phase==3 && !pending && !start;
    saved_cluster<=file_cluster;saved_size<=file_size;saved_position<=consume_position;
   end
   if(start) begin
    pending<=1;pending_resume<=resume_saved===1'b1 && saved_valid;restore_inflight<=resume_saved===1'b1 && saved_valid;
    pending_cluster<=resume_saved===1'b1 && saved_valid ? saved_cluster : start_cluster;
    pending_size<=resume_saved===1'b1 && saved_valid ? saved_size : start_size;enabled<=0;
   end
   if(pending && !start && state!=CACHE_WAIT) begin
    file_cluster<=pending_cluster;file_size<=pending_size;pending<=0;resume_active<=pending_resume;
    cache_valid<=0;position<=0;field<=0;phase<=0;fmt_ok<=0;riff_ok<=1;wave_ok<=1;enabled<=0;flush<=1;sample_byte<=0;
    sample_l<=0;sample_r<=0;status<=1;
    state<=pending_cluster>=2 && pending_size>=44 ? GET : IDLE;
    if(pending_cluster<2 || pending_size<44) status<=2; // no matching file
   end else case(state)
    IDLE:begin end
    GET:if(position>=file_size) state<=FAIL;
     else if(phase!=3 || sample_byte!=0 || room) begin
      if(!cache_valid || cache_sector!=position[31:9]) begin
       sector_addr<=position[31:9];sector_req<=1;received<=0;cache_valid<=0;state<=CACHE_WAIT;
      end else state<=PIPE;
     end
    CACHE_WAIT:begin
     if(sector_valid) begin sector_req<=0;received<=received+1'b1;end
     if(sector_done) begin
      sector_req<=0;cache_sector<=sector_addr;
      if(pending) state<=RESTART;
      else if(received==512 || (received==511 && sector_valid)) begin cache_valid<=1;state<=GET;end
      else state<=FAIL;
     end
    end
    PIPE:state<=USE;
    USE:begin
     position<=position+1'b1;field<=field+1'b1;state<=GET;
     case(phase)
      0:begin
       if(field<4) begin
        if((field==0 && q!="R") || (field==1 && q!="I") || (field>=2 && q!="F")) riff_ok<=0;
       end else if(field<8) riff_size[field[1:0]*8 +:8]<=q;
       else if((field==8 && q!="W") || (field==9 && q!="A") || (field==10 && q!="V") || (field==11 && q!="E")) wave_ok<=0;
       if(field==11) state<=HEADER_CHECK;
      end
      1:begin
       if(field<4) chunk_id[field[1:0]*8 +:8]<=q;
       else begin chunk_len[field[1:0]*8 +:8]<=q;chunk_mod3<=mod_digits%5'd3;end
       if(field==7) state<=CHUNK_PREP;
      end
      2:begin
       case(field)
        0:format[7:0]<=q;1:format[15:8]<=q;2:begin channels<=q[1:0];if(q[7:2]!=0)fields_ok<=0;end 3:if(q!=0)fields_ok<=0;
        4:rate_match<={q==8'h80,q==8'h44};5:rate_match<=rate_match & {q==8'hbb,q==8'hac};
        6,7:if(q!=0)rate_match<=0;
        12:begin align<=q[2:0];if(q[7:3]!=0)fields_ok<=0;end 13:if(q!=0)fields_ok<=0;14:bits<=q;15:if(q!=0)fields_ok<=0;
        18:valid_bits<=q;19:if(q!=0)fields_ok<=0;
       endcase
       if(field>=24 && field<40 && q!=guid_byte) subtype_ok<=0;
       if((field==15 && (format!=16'hfffe || chunk_len<40)) || field==39) state<=FMT_CHECK;
      end
      3:begin
       if(bits==16) case(sample_byte)
        0:sample_l[15:8]<=q;
        1:begin sample_l<=assembled;if(channels==1) sample_r<=assembled;end
        2:sample_r[15:8]<=q;
        3:sample_r<=assembled_r;
       endcase
       else case(sample_byte)
        0:sample_l[7:0]<=q;1:sample_l[15:8]<=q;
        2:begin sample_l<=assembled;if(channels==1) sample_r<=assembled;end
        3:sample_r[7:0]<=q;4:sample_r[15:8]<=q;5:sample_r<=assembled_r;
       endcase
       if(sample_byte+1==align) begin sample_byte<=0;push<=1;end
       else sample_byte<=sample_byte+1'b1;
       if(position==last_data_byte) begin position<=data_start;sample_byte<=0;end
      end
     endcase
    end
    HEADER_CHECK:if(!riff_ok || !wave_ok || riff_size<36 ||
       {1'b0,riff_size}+33'd8>{1'b0,file_size}) state<=FAIL;
     else begin riff_end<=riff_size+8;phase<=1;field<=0;state<=GET;end
    CHUNK_PREP:begin chunk_limit<={1'b0,position}+{1'b0,chunk_len};state<=CHUNK_CHECK;end
    CHUNK_CHECK:begin
     if(chunk_limit>{1'b0,riff_end} || chunk_limit[32]) state<=FAIL;
     else if(chunk_id==32'h20746d66 && chunk_len>=16) begin
      chunk_end<=chunk_limit[31:0]+chunk_len[0];phase<=2;field<=0;state<=GET;fields_ok<=1;subtype_ok<=1;rate_match<=0;
     end else if(chunk_id==32'h61746164) begin
      if(!fmt_ok || chunk_len==0 || !data_aligned) state<=FAIL;
      else begin data_start<=position;data_end<=chunk_limit[31:0];sample_byte<=0;
       phase<=3;enabled<=1;status<=3;state<=GET;
       if(resume_active && saved_position>=position && saved_position<chunk_limit[31:0]) begin
        position<=saved_position;consume_position<=saved_position;restore_pcm<=1;
       end else consume_position<=position;
       resume_active<=0;end
     end else if(chunk_limit+chunk_len[0]+8>{1'b0,riff_end}) state<=FAIL;
     else begin position<=chunk_limit[31:0]+chunk_len[0];field<=0;state<=GET;end
    end
    FMT_CHECK:if(!fields_ok || (format!=1 && !(format==16'hfffe && chunk_len>=40 && valid_bits==bits && subtype_ok)) || (channels!=1 && channels!=2) || (bits!=16 && bits!=24) ||
        (rate_match==0) || align!=(bits==16 ? ({2'b0,channels}<<1) : channels*3) || chunk_end+8>riff_end) state<=FAIL;
     else begin fmt_ok<=1;rate_44100<=rate_match[0];position<=chunk_end;phase<=1;field<=0;state<=GET;end
    FAIL:begin enabled<=0;flush<=1;status<=4;state<=IDLE;end
    RESTART:state<=IDLE;
   endcase
   if(underrun) status<=5;
   else if(status==5 && buffered>=256) status<=3;
  end
 end
endmodule
