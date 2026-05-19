`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: ip_parser
// Project Name: 
// Target Devices: Arty A7 35t
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


module ip_parser(
    input logic clk,
    input logic rst,
    input logic [7:0] payload, //from eth parser
    input logic payload_valid,
    input logic header_valid,
    input logic [15:0] ether,
    input logic frame_done,
    input logic error,
    
    //header fields
    output logic [3:0] ip_version,
    output logic [3:0]ip_ihl,
    output logic [7:0] ip_dscp,
    output logic [15:0] ip_total_len,
    output logic [15:0] ip_id,
    output logic [2:0] ip_flags,
    output logic [12:0] ip_frag_offset,
    output logic [7:0] ip_ttl,
    output logic [7:0] ip_protocol, //6 is tcp, 7=udp, 1=icmp
    output logic [15:0] ip_checksum,
    output logic [31:0] ip_src,
    output logic [31:0] ip_dest,
    output logic ip_header_valid,
    output logic ip_checksum_val,
    output logic ip_is_fragment,
    
    output logic [7:0] ip_payload_data,
    output logic ip_payload_valid,
    output logic ip_payload_done,
    output logic ip_error
);
endmodule
