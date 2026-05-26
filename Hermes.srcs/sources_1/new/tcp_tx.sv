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
    input logic load_seq, //one cycle pulse

    input logic start,
    output logic done,

    input logic [7:0] payload_in_data, //from ilink_tx
    input logic payload_in_valid,
    output logic payload_in_ready,

    output logic [7:0] payload_data, //to ip_tx
    output logic payload_valid,
    input logic payload_ready
    );
    
logic [31:0] seq_num;

logic [31:0] csum_static;
assign csum_static = {16'h0, src_ip[31:16]}
                   + {16'h0, src_ip[15:0]}
                   + {16'h0, dst_ip[31:16]}
                   + {16'h0, dst_ip[15:0]}
                   + 32'h0006
                   + {16'h0, tcp_length}
                   + {16'h0, src_port}
                   + {16'h0, dst_port}
                   + {16'h0, seq_num[31:16]}
                   + {16'h0, seq_num[15:0]}
                   + {16'h0, ack_num[31:16]}
                   + {16'h0, ack_num[15:0]}
                   + {16'h0, {8'h50, flags}}
                   + {16'h0, window_size};
//0x5000 = data_offset 5 << 12; urgent ptr and checksum placeholder are zero

logic [16:0] csum_fold1;
logic [15:0] csum_fold2;
logic [16:0] csum_with_payload;
logic [15:0] csum_prefinal;
logic [15:0] checksum;

assign csum_fold1 = {1'b0, csum_static[15:0]} + {1'b0, csum_static[31:16]};
assign csum_fold2 = csum_fold1[15:0] + {15'h0, csum_fold1[16]};
assign csum_with_payload = {1'b0, csum_fold2} + {1'b0, payload_csum};
assign csum_prefinal = csum_with_payload[15:0] + {15'h0, csum_with_payload[16]};
assign checksum = ~csum_prefinal;

typedef enum logic [1:0] {
    idle, header, data
} state_t;

state_t state;
logic [4:0] cnt;
logic [15:0] byte_cnt;


endmodule
