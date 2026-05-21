`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 12:04:00 PM
// Design Name: 
// Module Name: eth_tx
// Project Name: 
// Target Devices: 
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


module eth_tx(
    input  logic        tx_clk,
    input  logic        rst,

    input  logic [47:0] dst_mac, //for ip/icmp
    input  logic [15:0] ether_type,
    input  logic [7:0]  payload_data,
    input  logic        payload_valid,
    input  logic        start,
    output logic        payload_ready,
    output logic        done,

    output logic [7:0]  txd, //for mii
    output logic        tx_valid,
    input  logic        tx_ready
    );
    
localparam logic [47:0] SRC = 48'h00183E03E41B;

typedef enum logic [2:0] {
    idle, dst, src, ether, payload
} state_t;

always_ff @(posedge tx_clk) begin

end    
endmodule
