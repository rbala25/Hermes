`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/24/2026 08:00:55 PM
// Design Name: 
// Module Name: mdp_parser_tb
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


module mdp_parser_tb;

logic clk = 0;
always #10 clk = ~clk;

logic rst;
logic [7:0] udp_payload;
logic udp_payload_valid;
logic udp_payload_done;
logic udp_header_valid;
logic [15:0] udp_dest;
logic udp_error;
logic [31:0] mdp_seq_num;
logic [63:0] mdp_sending_time;
logic mdp_pkt_valid;
logic [63:0] entry_price;
logic [31:0] entry_size;
logic [7:0] entry_price_level;
logic [7:0] entry_update_action;
logic [7:0] entry_type;
logic is_snapshot;
logic entry_valid;
logic mdp_done;
logic mdp_error;

mdp_parser #(
    .port(16'd14310),
    .sec_id(32'd12345)
) dut (
    .clk(clk),
    .rst(rst),
    .udp_payload(udp_payload),
    .udp_payload_valid(udp_payload_valid),
    .udp_payload_done(udp_payload_done),
    .udp_header_valid(udp_header_valid),
    .udp_dest(udp_dest),
    .udp_error(udp_error),
    .mdp_seq_num(mdp_seq_num),
    .mdp_sending_time(mdp_sending_time),
    .mdp_pkt_valid(mdp_pkt_valid),
    .entry_price(entry_price),
    .entry_size(entry_size),
    .entry_price_level(entry_price_level),
    .entry_update_action(entry_update_action),
    .entry_type(entry_type),
    .is_snapshot(is_snapshot),
    .entry_valid(entry_valid),
    .mdp_done(mdp_done),
    .mdp_error(mdp_error)
);


endmodule
