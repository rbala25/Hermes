`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 02:48:57 PM
// Design Name: 
// Module Name: tcp_tx
// Project Name: 
// Target Devices: Arty A7 35t 
// Tool Versions: 
// Description: for iLink3 tx side
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tcp_tx(
    input logic tx_clk,
    input logic rst,

    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [15:0] tcp_length, //20 + payload length

    input logic [15:0] src_port, //header fields
    input logic [15:0] dst_port,
    input logic [31:0] ack_num,
    input logic [7:0] flags, 
    input logic [15:0] window_size,

    input logic [15:0] payload_csum,

    input logic [31:0] init_seq,
    input logic load_seq,

    input logic start,
    output logic done,

    input logic [7:0] payload_in_data, //from ilink_tx
    input logic payload_in_valid,
    output logic payload_in_ready,

    output logic [7:0] payload_data, //to ip_tx
    output logic payload_valid,
    input logic payload_ready
    );
endmodule
