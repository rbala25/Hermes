`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/24/2026 12:04:08 AM
// Design Name: 
// Module Name: mdp_parser
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


module mdp_parser #(
    parameter logic [15:0] port = 16'd14310
)(
    input logic clk,
    input logic rst,

    input logic [7:0] udp_payload,//from udp
    input logic udp_payload_valid,
    input logic udp_payload_done,
    input logic udp_header_valid,
    input logic [15:0] udp_dest,
    input logic udp_error,

    output logic [31:0] mdp_seq_num,
    output logic [63:0] mdp_sending_time,
    output logic mdp_pkt_valid, //pulse when header done (the 12 bit header)

    output logic [63:0] entry_price, //MDEntryPx PRICE9 (10^9)
    output logic [31:0] entry_size, 
    output logic [31:0] entry_security_id, //security id
    output logic [7:0] entry_price_level, //md price level 1-10
    output logic [7:0] entry_update_action, //0 = new, 1 = change, 2 = delete
    output logic [7:0] entry_type, //0x30=Bid 0x31=Ask
    output logic [15:0] entry_template_id, // 46=incremental 38=snapshot
    output logic entry_valid, //pulses for each entry WITHIN an SBE (can be multiple depending on msg size)
    output logic mdp_done, //all SBEs done
    output logic mdp_error
);

typedef enum logic [3:0] {
    idle,
    seq,
    mdp_time,
    size,
    hdr,
    root_46,
    dimensions,
    entry,
    root_38,
    dimensions_38,
    entry_38,
    skip
} state_t;


endmodule
