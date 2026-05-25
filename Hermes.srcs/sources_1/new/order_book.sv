`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/25/2026 12:07:14 AM
// Design Name: 
// Module Name: order_book
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


module order_book(
    input logic clk,
    input logic rst,
 
    input logic [63:0] entry_price, //price9 from mdp
    input logic [31:0] entry_size, // # contracts
    input logic [7:0] entry_price_level, //1-10, 1 = best
    input logic [7:0] entry_update_action, // 0=New 1=Change 2=Delete
    input logic [7:0] entry_type, // 0x30=Bid 0x31=Ask
    input logic is_snapshot, //1 if from T38 snapshot
    input logic entry_valid,
    input logic mdp_done,
    input logic [31:0] mdp_seq_num,
    input logic mdp_pkt_valid,
 
    output logic [63:0] best_bid_price, //combinational
    output logic [31:0] best_bid_size,
    output logic [63:0] best_ask_price,
    output logic [31:0] best_ask_size,
 
    input logic [3:0] rd_level, //drive 1-10
    input logic rd_side, //0 buy 1 ask
    output logic [63:0] rd_price,
    output logic [31:0] rd_size,
 
    output logic book_valid, //status indicator
    output logic gap_detected,
 
    output logic [1:0] book_state_dbg //for ila
    );
    
    typedef enum logic [1:0] {
        wait_s,
        live,
        gap //wait for t38
    } book_state_t;
     
    book_state_t book_state;
     
    localparam logic [7:0] BID_TYPE = 8'h30;
    localparam logic [7:0] ACT_NEW = 8'd0;
    localparam logic [7:0] ACT_CHANGE = 8'd1;
    localparam logic [7:0] ACT_DELETE = 8'd2;
    
    logic [63:0] bid_price [0:9]; //storage
    logic [31:0] bid_size [0:9];
    logic [63:0] ask_price [0:9];
    logic [31:0] ask_size [0:9];
    
endmodule
