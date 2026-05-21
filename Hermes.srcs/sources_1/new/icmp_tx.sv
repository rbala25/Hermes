`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 01:43:51 PM
// Design Name: 
// Module Name: icmp_tx
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


module icmp_tx(
    input logic tx_clk,
    input logic rst,

    input logic [15:0] identifier,
    input logic [15:0] seq,
    input logic [15:0] icmp_checksum, //has to be computed in top

    input logic start,
    output logic done,

    input logic [7:0] payload_in_data,
    input logic payload_in_valid,
    output logic payload_in_ready,

    output logic [7:0] payload_data, //for ip_tx
    output logic payload_valid,
    input logic payload_ready
    );
endmodule
