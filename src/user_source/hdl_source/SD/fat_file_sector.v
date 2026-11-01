// Read-only FAT32 logical-file-sector translation, including fragmented files.
// A per-stream cluster cursor makes sequential access O(1) per sector.
module fat_file_sector #(parameter PREFETCH_NEXT=0)(
 input clk,rst,input fat_mode,input [31:0] fat_lba,data_lba,max_cluster,
 input [2:0] cluster_shift,input [31:0] first_cluster,file_size,
 input req,input [31:0] sector,
 output [7:0] data,output valid,output done,
 output reg disk_req,output reg [31:0] disk_addr,
 input [7:0] disk_data,input disk_valid,disk_done
);
 localparam IDLE=0,SEEK=1,FAT_WAIT=2,FAT_CHECK=3,DATA_WAIT=4,ERROR=5,GAP=6;
 // A FAT file is at most 2^32-1 bytes: sector ordinals need only 23 bits.
 // Cluster size is at most 128 sectors: offset needs only 7 bits.
 reg [2:0] state;reg [31:0] key,cursor;reg [22:0] ordinal,target;reg [6:0] offset;
 reg [31:0] link;reg [9:0] count;reg [8:0] entry_offset;
 reg follow_valid;reg [31:0] follow_key,follow_link;
 reg cached;wire [31:0] cluster_mask=(32'd1<<cluster_shift)-1;
 assign data=disk_data;
 assign valid=state==DATA_WAIT && disk_valid;
 assign done=(state==DATA_WAIT && disk_done) || state==ERROR;
 always @(posedge clk or posedge rst) begin
  if(rst) begin state<=IDLE;key<=0;cursor<=0;ordinal<=0;target<=0;offset<=0;
   follow_valid<=0;follow_key<=0;follow_link<=0;link<=0;count<=0;entry_offset<=0;cached<=0;disk_req<=0;disk_addr<=0;end
  else case(state)
   IDLE:if(req) begin
    if(!fat_mode) begin disk_addr<=sector;disk_req<=1;state<=DATA_WAIT;end
    else if(first_cluster<2 || first_cluster>max_cluster || file_size==0 || sector>((file_size-1)>>9)) state<=ERROR;
    else begin
     target<=sector[22:0]>>cluster_shift;offset<=sector[6:0]&cluster_mask[6:0];
     if(!cached || key!=first_cluster || (sector[22:0]>>cluster_shift)<ordinal) begin
      key<=first_cluster;cursor<=first_cluster;ordinal<=0;cached<=1;follow_valid<=0;
     end
     state<=SEEK;
    end
   end
   SEEK:if(cursor<2 || cursor>max_cluster) begin cached<=0;state<=ERROR;end
    else if(ordinal==target) begin
     disk_addr<=data_lba+((cursor-2)<<cluster_shift)+offset;disk_req<=1;state<=DATA_WAIT;
    end else if(PREFETCH_NEXT && follow_valid && follow_key==cursor) begin
     link<=follow_link;count<=512;follow_valid<=0;state<=FAT_CHECK;
    end else begin
     follow_valid<=0;follow_key<=cursor+1;follow_link<=0;
     disk_addr<=fat_lba+(cursor>>7);entry_offset<={cursor[6:0],2'b00};
     disk_req<=1;count<=0;link<=0;state<=FAT_WAIT;
    end
   FAT_WAIT:begin
    if(disk_valid) begin
     disk_req<=0;count<=count+1'b1;
     if(PREFETCH_NEXT && cursor[6:0]!=127 && count[8:2]==cursor[6:0]+7'd1)
      case(count[1:0]) 0:follow_link[7:0]<=disk_data;1:follow_link[15:8]<=disk_data;
       2:follow_link[23:16]<=disk_data;3:follow_link[31:24]<={4'b0,disk_data[3:0]};endcase
     // FAT entries are four-byte aligned; compare entry indices directly.
     if(!count[9] && count[8:2]==entry_offset[8:2])
      case(count[1:0]) 0:link[7:0]<=disk_data;1:link[15:8]<=disk_data;
       2:link[23:16]<=disk_data;3:link[31:24]<={4'b0,disk_data[3:0]};endcase
    end
    if(disk_done) begin disk_req<=0;follow_valid<=PREFETCH_NEXT && cursor[6:0]!=127 && count==512;state<=FAT_CHECK;end
   end
   FAT_CHECK:if(count!=512 || link<2 || link>max_cluster || link==cursor) begin cached<=0;state<=ERROR;end
    else begin cursor<=link;ordinal<=ordinal+1'b1;state<=SEEK;end
   DATA_WAIT:begin
    if(disk_valid) disk_req<=0;
    if(disk_done) begin disk_req<=0;state<=GAP;end
   end
   ERROR:state<=GAP;
   GAP:state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule
