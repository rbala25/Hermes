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

typedef enum logic [2:0] {
    idle, header, payload_state, csum_check
} state_t;
 
state_t state;
logic [4:0] cnt;
logic [7:0] hdr [0:19]; //raw header byte capture
logic [15:0] rx_checksum;
logic [31:0] payload_csum_acc;
logic payload_byte_toggle; //phase
logic [7:0] payload_byte_hold;

logic [31:0] csum_static;
assign csum_static = {16'h0, src_ip[31:16]} + {16'h0, src_ip[15:0]} + {16'h0, dst_ip[31:16]} + {16'h0, dst_ip[15:0]} + 32'h0006
                   + {16'h0, tcp_length} + {16'h0, src_port} + {16'h0, dst_port} + {16'h0, seq_num[31:16]} + {16'h0, seq_num[15:0]}
                   + {16'h0, ack_num[31:16]} + {16'h0, ack_num[15:0]} + {16'h0, {8'h50, flags}} + {16'h0, window_size} + {16'h0, rx_checksum}; //must sum to 0
 
logic [16:0] csum_fold1;
logic [15:0] csum_fold2;

assign csum_fold1 = {1'b0, csum_static[15:0]} + {1'b0, csum_static[31:16]};
assign csum_fold2 = csum_fold1[15:0] + {15'h0, csum_fold1[16]};
    
endmodule
