`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: udp_parser
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


module udp_parser(
    input logic clk,
    input logic rst_n,
    input logic payload_valid, //from ip_parser
    input logic payload_sop,
    input logic payload_eop, //end of packet
    input logic [7:0] payload,
    input logic [31:0] ip_src,
    input logic [31:0] ip_dest,
    
    output logic [15:0] udp_src, //parsed outputs
    output logic [15:0] udp_dest,
    output logic [15:0] udp_length, //including 8 bit header
    output logic [15:0] udp_checksum,
    output logic udp_header_valid,
    output logic udp_checksum_valid,
    output logic [7:0] udp_payload,
    output logic udp_payload_valid,
    output logic udp_payload_eop
    );
endmodule
