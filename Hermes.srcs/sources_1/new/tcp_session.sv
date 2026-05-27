`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 07:47:41 PM
// Design Name: 
// Module Name: tcp_session
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


module tcp_session #(
    parameter CLK_FREQ = 25_000_000, 
    parameter RETRANSMIT_CYCLES = CLK_FREQ, //1 second retransmit timeout
    parameter KEEPALIVE_CYCLES = CLK_FREQ //1 second keepalive interval
)(
    input logic clk,
    input logic rst,
 
    input logic connect, 
    input logic disconnect, //pulse
 
    input logic [15:0] src_port,
    input logic [15:0] dst_port,
    input logic [15:0] window_size,
    input logic [31:0] isn,
 
    input logic rx_syn,//tcp rx
    input logic rx_ack,
    input logic rx_fin,
    input logic rx_rst,
    input logic [31:0] rx_seq_num, 
    input logic header_valid, 
 

    output logic ctrl_start, //tcp tx
    output logic [7:0] ctrl_flags,
    output logic [31:0] ctrl_ack_num,
    output logic [15:0] ctrl_tcp_length, 
    output logic [15:0] ctrl_payload_csum,
    input logic tx_done,
 
    output logic load_seq,//pulse
    output logic [31:0] init_seq,
 
    output logic tx_grant, //high when established and tcp_tx is free
 
    output logic established,
    output logic closed
);

endmodule
