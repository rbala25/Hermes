`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2026 01:37:29 PM
// Design Name: 
// Module Name: ip_parser_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ip_parser_tb();
logic clk; //inputs
logic rst;
logic[7:0] payload;
logic payload_valid;
logic header_valid;
logic[15:0] ether;
logic frame_done;
logic error;
 
logic[3:0] ip_version; //outputs
logic[3:0] ip_ihl;
logic[7:0] ip_dscp;
logic[15:0] ip_total_len;
logic[15:0] ip_id;
logic[2:0] ip_flags;
logic[12:0] ip_frag_offset;
logic[7:0] ip_ttl;
logic[7:0] ip_protocol;
logic[15:0] ip_checksum;
logic[31:0] ip_src;
logic[31:0] ip_dest;
logic ip_header_valid;
logic ip_checksum_val;
logic ip_is_fragment;
logic[7:0] ip_payload_data;
logic ip_payload_valid;
logic ip_payload_done;
logic ip_error;

ip_parser dut(.*);

initial clk = 0;
always #20 clk = ~clk; //25Mhz

int pass_count = 0;
int fail_count = 0;

endmodule
