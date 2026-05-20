`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/20/2026 05:27:32 PM
// Design Name: 
// Module Name: icmp_parser
// Project Name: 
// Target Devices: 
// Tool Versions: Arty A7 35t
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module icmp_parser(
    input logic clk,
    input logic rst,
    input logic [7:0] payload,
    input logic payload_valid,
    input logic ip_header_valid,
    input logic ip_payload_done,
    input logic [7:0] ip_protocol,
    input logic error,
 
    output logic [7:0] icmp_type,
    output logic [7:0] icmp_code,
    output logic [15:0] icmp_checksum,
    output logic [15:0] icmp_identifier, //echo only
    output logic [15:0] icmp_seq_num, //echo only
    output logic icmp_header_valid, 
    output logic icmp_checksum_val,
    output logic [7:0] icmp_payload_data,
    output logic icmp_payload_valid,
    output logic icmp_payload_done,
    output logic icmp_error
    );
endmodule
