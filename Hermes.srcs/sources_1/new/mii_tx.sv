`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 01:26:20 AM
// Design Name: 
// Module Name: mii_tx
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


module mii_tx(
    input  logic tx_clk,
    input  logic rst,
    input  logic [7:0] data,
    input  logic valid,
    
    output logic ready,
    output logic [3:0] txd,
    output logic tx_en
    );
endmodule
