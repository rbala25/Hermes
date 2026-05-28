`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/28/2026 12:25:43 AM
// Design Name: 
// Module Name: mm_top
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


module mm_top #(
    parameter logic [47:0] MY_MAC = 48'h00183E03E41B,
    parameter logic [31:0] MY_IP = 32'hC0A80164,
    parameter logic [31:0] CME_IP = 32'hC0A80101,
    parameter logic [15:0] CME_PORT = 16'd10000,
    parameter logic [15:0] SRC_PORT = 16'd12345,
    parameter logic [31:0] ISN = 32'hDEADBEEF,
    parameter logic [31:0] SEC_ID = 32'd0,
    parameter logic [15:0] MDP_PORT = 16'd14310,
    parameter logic [63:0] HALF_SPREAD = 64'd250000000,
    parameter logic [31:0] MAX_POSITION = 32'd10,
    parameter logic [31:0] QUOTE_SIZE = 32'd1,
    parameter logic [15:0] MAX_ORDER_RATE = 16'd100,
    parameter logic [63:0] LOSS_LIMIT = 64'd5000000000000,
    parameter logic [3:0] VWAP_LEVELS = 4'd5,
    parameter logic [63:0] SKEW_PER_CONTRACT = 64'd25000000,
    parameter logic [24:0] REFRESH_TICKS = 25'd2,
    parameter logic [31:0] CLK_FREQ = 32'd25000000,
    parameter logic [31:0] OFI_DECAY_TICKS = 32'd1000,
    parameter logic [63:0] OFI_SCALE = 64'd25000000,
    parameter logic [31:0] OFI_THRESHOLD = 32'd10,
    parameter logic [31:0] RETRANSMIT_CYCLES = 32'd25000000,
    parameter logic [31:0] KEEPALIVE_CYCLES = 32'd625000000,
    parameter logic [255:0] HMAC_NEGOTIATE = 256'd0,
    parameter logic [255:0] HMAC_ESTABLISH = 256'd0
)(
    input logic rx_clk,
    input logic tx_clk,
    input logic rst,
    input logic [3:0] rxd,
    input logic rx_dv,
    output logic [3:0] txd,
    output logic tx_en,
    output logic uart_tx,
    output logic [3:0] led
);


endmodule
