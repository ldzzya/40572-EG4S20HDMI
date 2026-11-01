// FAT32 root: four numeric BMP/WAV pairs in slots 0..3, in directory order.
// WARNING.BMP/WARNING.WAV use independent slot 4, never part of image_count.
// Other names and file types (including WARNING.PNG) are ignored.
// First pass collects BMPs; second pass matches WAVs regardless of entry order.
// Supports a FAT32 superfloppy or the first FAT32 primary MBR partition.
module fat32_catalog(
 input clk,rst,card_ready, input [2:0] index,
 output reg mounted,fat_ok,output reg [2:0] image_count,
 output [31:0] bmp_cluster,bmp_size,wav_cluster,wav_size,
 output reg [31:0] fat_lba,data_lba,max_cluster,
 output reg [2:0] cluster_shift,
 output reg disk_req,output reg [31:0] disk_addr,
 input [7:0] disk_data,input disk_valid,disk_done,
 output reg priority_found,output [2:0] priority_index,
 output background_found,output [31:0] background_cluster,background_size
);
 // Isolate the sector RAM output from directory-entry byte classification.
 reg [7:0] disk_data_q;reg disk_valid_q,disk_done_q;
 always @(posedge clk)disk_data_q<=disk_data;
 always @(posedge clk or posedge rst)
  if(rst)begin disk_valid_q<=0;disk_done_q<=0;end
  else begin disk_valid_q<=disk_valid;disk_done_q<=disk_done;end

 localparam INIT=0,BOOT_WAIT=1,BOOT_CHECK=2,DIR_START=3,DIR_WAIT=4,
 DIR_NEXT=5,FAT_WAIT=6,FAT_CHECK=7,PASS_END=8,READY=9,BAD=10;
 reg [3:0] state;reg [9:0] pos;
 reg [31:0] base,partition,partition_tmp,total,reserved32,fatsz,root,cluster,next_cluster;
 reg [15:0] reserved,flags;
 reg [1:0] bps_ok,root_entries_ok,fat16_ok,version_ok,signature_ok;
 reg [7:0] spc,fats,partition_type;
 reg [6:0] dir_sector;reg [13:0] visited;reg second_pass,end_dir;
 // Eight decimal filename digits need at most 27 bits (99,999,999).
 reg [26:0] ids[0:3],number;
 reg [31:0] bc[0:4],bs[0:4],wc[0:4],ws[0:4];
 reg name_ok,name_digit,name_space,entry_live,warning_name;reg [31:0] entry_cluster,entry_size;
 reg [23:0] extension;reg [7:0] attr;
 wire [4:0] ep=pos[4:0];
 // Keep the old unused background outputs tied off for the v12 interface.
 assign background_found=1'b0;assign background_cluster=32'd0;assign background_size=32'd0;
 assign priority_index=3'd4;
 reg [7:0] warning_letter;
 always @* case(ep)
  1:warning_letter="a";2:warning_letter="r";3:warning_letter="n";
  4:warning_letter="i";5:warning_letter="n";6:warning_letter="g";
  default:warning_letter=8'd32;
 endcase
 wire duplicate=(image_count>0 && ids[0]==number)||(image_count>1 && ids[1]==number)||
                (image_count>2 && ids[2]==number)||(image_count>3 && ids[3]==number);
 wire [1:0] slot=image_count[1:0];
 wire [31:0] entry_length={disk_data_q,entry_size[23:0]};
 wire spc_ok=spc!=0 && spc<=128 && ((spc&(spc-1'b1))==0);
 wire [31:0] overhead_calc={16'b0,reserved}+(fats==2 ? (fatsz<<1) : fatsz);
 reg [31:0] overhead;
 assign bmp_cluster=index<5 ? bc[index] : 32'd0;assign bmp_size=index<5 ? bs[index] : 32'd0;
 assign wav_cluster=index<5 ? wc[index] : 32'd0;assign wav_size=index<5 ? ws[index] : 32'd0;
 integer i;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   warning_name<=0;priority_found<=0;entry_live<=0;state<=INIT;pos<=0;base<=0;partition<=0;partition_tmp<=0;partition_type<=0;
   total<=0;reserved32<=0;fatsz<=0;root<=0;cluster<=0;next_cluster<=0;
   overhead<=0;bps_ok<=0;reserved<=0;root_entries_ok<=0;fat16_ok<=0;flags<=0;version_ok<=0;signature_ok<=0;spc<=0;fats<=0;
   dir_sector<=0;visited<=0;second_pass<=0;end_dir<=0;name_ok<=0;name_digit<=0;name_space<=0;
   number<=0;entry_cluster<=0;entry_size<=0;extension<=0;attr<=0;
   mounted<=0;fat_ok<=0;image_count<=0;fat_lba<=0;data_lba<=0;max_cluster<=0;cluster_shift<=0;
   disk_req<=0;disk_addr<=0;
   for(i=0;i<4;i=i+1) ids[i]<=0;
   for(i=0;i<5;i=i+1) begin bc[i]<=0;bs[i]<=0;wc[i]<=0;ws[i]<=0;end
  end else begin
   if(disk_valid_q) begin disk_req<=0;pos<=pos+1'b1;end
   if(disk_done_q) disk_req<=0;
   case(state)
    INIT:if(card_ready) begin disk_addr<=0;disk_req<=1;pos<=0;state<=BOOT_WAIT;end
    BOOT_WAIT:begin
     if(disk_valid_q) begin
      case(pos)
       11:bps_ok[0]<=disk_data_q==8'd0;12:bps_ok[1]<=disk_data_q==8'd2;13:spc<=disk_data_q;
       14:reserved[7:0]<=disk_data_q;15:reserved[15:8]<=disk_data_q;16:fats<=disk_data_q;
       17:root_entries_ok[0]<=disk_data_q==8'd0;18:root_entries_ok[1]<=disk_data_q==8'd0;
       22:fat16_ok[0]<=disk_data_q==8'd0;23:fat16_ok[1]<=disk_data_q==8'd0;
       32:total[7:0]<=disk_data_q;33:total[15:8]<=disk_data_q;34:total[23:16]<=disk_data_q;35:total[31:24]<=disk_data_q;
       36:fatsz[7:0]<=disk_data_q;37:fatsz[15:8]<=disk_data_q;38:fatsz[23:16]<=disk_data_q;39:fatsz[31:24]<=disk_data_q;
       40:flags[7:0]<=disk_data_q;41:flags[15:8]<=disk_data_q;
       42:version_ok[0]<=disk_data_q==8'd0;43:version_ok[1]<=disk_data_q==8'd0;
       44:root[7:0]<=disk_data_q;45:root[15:8]<=disk_data_q;46:root[23:16]<=disk_data_q;47:root[31:24]<={4'b0,disk_data_q[3:0]};
       510:signature_ok[0]<=disk_data_q==8'd85;511:signature_ok[1]<=disk_data_q==8'd170;
      endcase
      if(base==0 && pos>=446 && pos<510) case((pos-446)&15)
       4:partition_type<=disk_data_q;
       8:partition_tmp[7:0]<=disk_data_q;9:partition_tmp[15:8]<=disk_data_q;
       10:partition_tmp[23:16]<=disk_data_q;
       11:if(partition==0 && (partition_type==8'h0b || partition_type==8'h0c))
         partition<={disk_data_q,partition_tmp[23:0]};
      endcase
     end
     if(disk_done_q) begin overhead<=overhead_calc;state<=BOOT_CHECK;end
    end
    BOOT_CHECK:begin
     if(pos==512 && (&signature_ok) && (&bps_ok) && spc_ok && reserved!=0 &&
        (fats==1 || fats==2) && (&root_entries_ok) && (&fat16_ok) && fatsz!=0 &&
        (&version_ok) && root>=2 && total>overhead && (!flags[7] || flags[3:0]<fats)) begin
      case(spc) 1:cluster_shift<=0;2:cluster_shift<=1;4:cluster_shift<=2;8:cluster_shift<=3;
       16:cluster_shift<=4;32:cluster_shift<=5;64:cluster_shift<=6;128:cluster_shift<=7;endcase
      fat_lba<=base+reserved+(flags[7] && flags[3:0]==1 ? fatsz : 0);
      data_lba<=base+overhead;reserved32<=total-overhead;
      cluster<=root;dir_sector<=0;visited<=0;end_dir<=0;state<=DIR_START;
     end else if(base==0 && partition!=0 && pos==512 && (&signature_ok)) begin
      base<=partition;disk_addr<=partition;pos<=0;disk_req<=1;state<=BOOT_WAIT;
     end else state<=BAD;
    end
    DIR_START:begin
     max_cluster<=(reserved32>>cluster_shift)+1;
     if(cluster<2 || cluster>=(reserved32>>cluster_shift)+2 || visited>=8192) state<=BAD;
     else begin
      disk_addr<=data_lba+((cluster-2)<<cluster_shift)+dir_sector;
      disk_req<=1;pos<=0;visited<=visited+1'b1;state<=DIR_WAIT;
     end
    end
    DIR_WAIT:begin
     if(disk_valid_q && !end_dir) begin
      if(ep==0) begin
       entry_live<=disk_data_q!=0 && disk_data_q!=8'he5;
       warning_name<=(disk_data_q|8'h20)=="w";
       name_ok<=disk_data_q>="0" && disk_data_q<="9";name_digit<=disk_data_q>="0" && disk_data_q<="9";
       name_space<=0;number<=disk_data_q-8'd48;
       if(disk_data_q==0) end_dir<=1;
      end else if(ep<8) begin
       if(ep==7 ? disk_data_q!=32 : (disk_data_q|8'h20)!=warning_letter) warning_name<=0;
       if(disk_data_q==32) name_space<=1;
       else if(disk_data_q>="0" && disk_data_q<="9" && !name_space) number<=number*10+disk_data_q-8'd48;
       else name_ok<=0;
      end
      case(ep)
       8:extension[7:0]<=disk_data_q&8'hdf;9:extension[15:8]<=disk_data_q&8'hdf;10:extension[23:16]<=disk_data_q&8'hdf;
       11:attr<=disk_data_q;20:entry_cluster[23:16]<=disk_data_q;21:entry_cluster[31:24]<={4'b0,disk_data_q[3:0]};
       26:entry_cluster[7:0]<=disk_data_q;27:entry_cluster[15:8]<=disk_data_q;
       28:entry_size[7:0]<=disk_data_q;29:entry_size[15:8]<=disk_data_q;30:entry_size[23:16]<=disk_data_q;
       31:if(entry_live && (attr&8'h18)==0 && entry_cluster>=2 && entry_cluster<=max_cluster && entry_length!=0) begin
        if(!second_pass && extension==24'h504d42) begin
         if(warning_name && !priority_found) begin
          bc[4]<=entry_cluster;bs[4]<=entry_length;priority_found<=1;
         end else if(name_ok && name_digit && image_count<4 && !duplicate) begin
          ids[slot]<=number;bc[slot]<=entry_cluster;bs[slot]<=entry_length;
          image_count<=image_count+1'b1;
         end
        end
        if(second_pass && extension==24'h564157) begin
         if(warning_name && wc[4]==0) begin wc[4]<=entry_cluster;ws[4]<=entry_length;end
         else if(name_ok && name_digit)
          for(i=0;i<4;i=i+1) if(i<image_count && ids[i]==number && wc[i]==0) begin
           wc[i]<=entry_cluster;ws[i]<=entry_length;
          end
        end
       end
      endcase
     end
     if(disk_done_q) state<=DIR_NEXT;
    end
    DIR_NEXT:if(pos!=512) state<=BAD;
     else if(end_dir || (!second_pass && image_count==4 && priority_found)) state<=PASS_END;
     else if(dir_sector+8'd1<(8'd1<<cluster_shift)) begin dir_sector<=dir_sector+1'b1;state<=DIR_START;end
     else begin disk_addr<=fat_lba+(cluster>>7);pos<=0;next_cluster<=0;disk_req<=1;state<=FAT_WAIT;end
    FAT_WAIT:begin
     if(disk_valid_q && pos[8:2]==cluster[6:0]) case(pos[1:0])
      0:next_cluster[7:0]<=disk_data_q;1:next_cluster[15:8]<=disk_data_q;
      2:next_cluster[23:16]<=disk_data_q;3:next_cluster[31:24]<={4'b0,disk_data_q[3:0]};endcase
     if(disk_done_q) state<=FAT_CHECK;
    end
    FAT_CHECK:if(pos!=512) state<=BAD;
     else if(next_cluster>=32'h0ffffff8) state<=PASS_END;
     else if(next_cluster<2 || next_cluster>max_cluster || next_cluster==cluster) state<=BAD;
     else begin cluster<=next_cluster;dir_sector<=0;state<=DIR_START;end
    PASS_END:if(second_pass) begin mounted<=1;fat_ok<=1;state<=READY;end
     else begin second_pass<=1;cluster<=root;dir_sector<=0;visited<=0;end_dir<=0;state<=DIR_START;end
    BAD:begin mounted<=1;fat_ok<=0;image_count<=0;state<=READY;end
    READY:begin end
    default:state<=BAD;
   endcase
  end
 end
endmodule
