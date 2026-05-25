`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/25/2026 05:20:06 PM
// Design Name: 
// Module Name: mm_core
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


module mm_core #(
    parameter logic [63:0] HALF_SPREAD = 64'd5_000_000_000, // $5.00 price9
    parameter logic [31:0] MAX_POSITION = 32'd10, //# contracts
    parameter logic [31:0] QUOTE_SIZE = 32'd1,
    parameter logic [15:0] MAX_ORDER_RATE = 16'd10,
    parameter logic [63:0] LOSS_LIMIT = 64'd1_000_000_000_000, //$1000
    parameter logic [3:0] VWAP_LEVELS = 4'd3, 
    parameter logic [63:0] SKEW_PER_CONTRACT = 64'd1_000_000_000, //$1.00 per contract
    parameter logic [24:0] REFRESH_TICKS = 25'd1_000_000, //40 ms prevent stale quotes
    parameter logic [31:0] CLK_FREQ = 32'd25_000_000
)(
    input logic clk,
    input logic rst,

    input logic [63:0] best_bid_price,
    input logic [31:0] best_bid_size,
    input logic [63:0] best_ask_price,
    input logic [31:0] best_ask_size,
    input logic book_valid,
    input logic gap_detected,

    output logic [3:0] rd_level, //combinational
    output logic rd_side,
    input logic [63:0] rd_price,
    input logic [31:0] rd_size,

    input logic fill_valid,
    input logic [63:0] fill_price,
    input logic [31:0] fill_size,
    input logic fill_side, // 0 = buy fill, 1 = sell fill

    output logic [63:0] bid_price,
    output logic [31:0] bid_size,
    output logic [63:0] ask_price,
    output logic [31:0] ask_size,
    output logic quote_valid, //pulse means new quotes on bid_price/ask_price

    output logic cancel_bid, //pulse based
    output logic cancel_ask,

    output logic risk_breach
);

typedef enum logic [2:0] {
    idle,
    vwap_read,
    div_init,
    div_run,
    mid_calc,
    quote_calc,
    risk,
    emit
} state_t;

state_t state;

logic [127:0] sum_bid_weighted; //vwap
logic [63:0] sum_bid_size;
logic [127:0] sum_ask_weighted;
logic [63:0] sum_ask_size;
logic [4:0] vwap_cnt;

logic [64:0] div_P; // partial remainder
logic [63:0] div_A_lo;
logic [63:0] div_D;
logic [63:0] div_Q; //quotient
logic [5:0] div_cnt;
logic div_phase; //0 = bid, 1 = ask

logic [64:0] P_trial;
logic Q_bit;
assign P_trial = {div_P[63:0], div_A_lo[63]};
assign Q_bit = (P_trial >= {1'b0, div_D}) ? 1'b1 : 1'b0;

logic [63:0] bid_vwap;
logic [63:0] ask_vwap;
logic [63:0] mid_price; //computed prices

logic signed [31:0] net_position; //positive = long, neg = short (signed)
logic signed [127:0] daily_pnl;

logic [24:0] sec_counter; //goes to clk_freq - 1, resets order_count
logic [15:0] order_count;

logic [63:0] prev_best_bid;
logic [63:0] prev_best_ask;
logic fill_requote; //sticky
logic refresh_pending;
logic [24:0] refresh_counter;

logic signed [96:0] skew_product;
assign skew_product = $signed(net_position) * $signed({1'b0, SKEW_PER_CONTRACT}); //comb

logic signed [64:0] bid_q_raw;
logic signed [64:0] ask_q_raw;
assign bid_q_raw = $signed({1'b0, mid_price}) - $signed({1'b0, HALF_SPREAD}) - $signed(skew_product[64:0]); //signed
assign ask_q_raw = $signed({1'b0, mid_price}) + $signed({1'b0, HALF_SPREAD}) - $signed(skew_product[64:0]);


endmodule
