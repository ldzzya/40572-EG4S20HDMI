// Conservative FAT32 metadata skip for the existing raw BMP sector scanner.
// No directory or FAT-chain traversal: contiguous BMP storage is still required.
// Unknown/invalid layouts fall back to the original sequential scan.
module scan_address_hint(
 input clk,rst,restart,header_check,byte_valid,
 input [9:0] byte_index,input [7:0] byte_data,input [31:0] sector,
 output jump_valid,output [31:0] jump_sector
);
 reg [31:0] boot_sector,partition_lba,partition_size,fat_size,total_sectors,root_cluster;
 reg [15:0] reserved;
 // Fixed fields are consumed only as predicates. Keep byte comparison bits
 // rather than unused full-byte registers; reset matches the old zero fields.
 reg [1:0] sector_size_ok,root_entries_ok,fat16_ok,signature;
 reg partition_type_ok,boot_flag_ok;
 reg [7:0] fat_count,cluster_size;
 wire signature_ok=&signature;
 wire [32:0] partition_end={1'b0,partition_lba}+{1'b0,partition_size};
 wire mbr_ok=sector==0 && signature_ok && boot_flag_ok &&
  partition_type_ok && partition_lba!=0 &&
  partition_size!=0 && !partition_end[32];
 wire [32:0] metadata_sectors={17'b0,reserved}+
   (fat_count==2 ? ({1'b0,fat_size}<<1) : {1'b0,fat_size});
 wire [32:0] data_start={1'b0,sector}+metadata_sectors;
 wire cluster_ok=cluster_size!=0 && cluster_size<=128 &&
   ((cluster_size & (cluster_size-1'b1))==0);
 wire vbr_ok=sector==boot_sector && signature_ok && (&sector_size_ok) &&
  cluster_ok && reserved!=0 && (fat_count==1 || fat_count==2) &&
  (&root_entries_ok) && (&fat16_ok) && fat_size!=0 && fat_size<32'd1048576 &&
  root_cluster>=2 && total_sectors>metadata_sectors && !data_start[32];
 assign jump_valid=vbr_ok || mbr_ok;
 assign jump_sector=vbr_ok ? data_start[31:0] : partition_lba;
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   boot_sector<=0;partition_lba<=0;partition_size<=0;fat_size<=0;total_sectors<=0;
   root_cluster<=0;sector_size_ok<=2'b01;reserved<=0;root_entries_ok<=2'b11;fat16_ok<=2'b11;
   partition_type_ok<=0;boot_flag_ok<=1;fat_count<=0;cluster_size<=0;signature<=0;
  end else begin
   if(restart) boot_sector<=0;
   else if(header_check && mbr_ok && !vbr_ok) boot_sector<=partition_lba;
   if(byte_valid) case(byte_index)
    11:sector_size_ok[0]<=byte_data==0;12:sector_size_ok[1]<=byte_data==2;
    13:cluster_size<=byte_data;
    14:reserved[7:0]<=byte_data;15:reserved[15:8]<=byte_data;
    16:fat_count<=byte_data;
    17:root_entries_ok[0]<=byte_data==0;18:root_entries_ok[1]<=byte_data==0;
    22:fat16_ok[0]<=byte_data==0;23:fat16_ok[1]<=byte_data==0;
    32:total_sectors[7:0]<=byte_data;33:total_sectors[15:8]<=byte_data;
    34:total_sectors[23:16]<=byte_data;35:total_sectors[31:24]<=byte_data;
    36:fat_size[7:0]<=byte_data;37:fat_size[15:8]<=byte_data;
    38:fat_size[23:16]<=byte_data;39:fat_size[31:24]<=byte_data;
    44:root_cluster[7:0]<=byte_data;45:root_cluster[15:8]<=byte_data;
    46:root_cluster[23:16]<=byte_data;47:root_cluster[31:24]<=byte_data;
    446:boot_flag_ok<=byte_data==0 || byte_data==8'h80;
    450:partition_type_ok<=byte_data==8'h0b || byte_data==8'h0c;
    454:partition_lba[7:0]<=byte_data;455:partition_lba[15:8]<=byte_data;
    456:partition_lba[23:16]<=byte_data;457:partition_lba[31:24]<=byte_data;
    458:partition_size[7:0]<=byte_data;459:partition_size[15:8]<=byte_data;
    460:partition_size[23:16]<=byte_data;461:partition_size[31:24]<=byte_data;
    510:signature[0]<=byte_data==8'h55;511:signature[1]<=byte_data==8'haa;
   endcase
  end
 end
endmodule
