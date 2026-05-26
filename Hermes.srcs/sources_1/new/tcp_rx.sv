`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 04:32:06 PM
// Design Name: 
// Module Name: tcp_rx
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


module tcp_rx(
    input logic rx_clk,
    input logic rst,
 
    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [15:0] tcp_length,
 
    input logic [7:0] data_in, //incoming bytes
    input logic data_in_valid,
    output logic data_in_ready,
 
    output logic [15:0] src_port, //parsed header fields
    output logic [15:0] dst_port,
    output logic [31:0] seq_num,
    output logic [31:0] ack_num,
    output logic [7:0] flags,
    output logic [15:0] window_size,
    output logic header_valid, //single cycle pulse when all ok
 
    output logic [7:0] payload_data,
    output logic payload_valid,
    input logic payload_ready,
 
    output logic rx_syn, //to tcp_session
    output logic rx_ack,
    output logic rx_fin,
    output logic rx_rst,
    output logic csum_error //pulse when checksum fails
    );
endmodule
