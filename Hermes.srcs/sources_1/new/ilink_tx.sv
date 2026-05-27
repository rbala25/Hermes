`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 11:54:29 PM
// Design Name: 
// Module Name: ilink_tx
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


module ilink_tx #(
parameter [31:0] CLK_FREQ = 32'd25_000_000,
parameter [31:0] HB_INTERVAL = 32'd25_000_000, //1s
parameter [15:0] KEEP_ALIVE_MS = 16'd10_000, //10s

parameter [159:0] ACCESS_KEY_ID = 160'h0, 
parameter [63:0] SESSION_UUID = 64'h0, 
parameter [23:0] SESSION_ID = 24'h0,
parameter [39:0] FIRM_ID = 40'h0, 

parameter [239:0] SYS_NAME = 240'h0, //all these are just placeholders
parameter [79:0] SYS_VERSION = 80'h0,
parameter [79:0] SYS_VENDOR = 80'h0, 

parameter [63:0] PARTY_DETAILS_REQ_ID = 64'hFFFFFFFFFFFFFFFF, 
parameter [159:0] SENDER_ID = 160'h0,
parameter [39:0] LOCATION = 40'h0,
parameter [31:0] SECURITY_ID = 32'h0
)(
    input logic clk,
    input logic rst,
 
    input logic established, //tcp connected
 
    //FIXP session credentials
    input logic [255:0] hmac_negotiate,
    input logic [255:0] hmac_establish,
    input logic [63:0] req_timestamp,
 
    input logic neg_response, //responses
    input logic estab_ack,
 
    output logic ilink_established, //high when FIXP session is up
 
    input logic tx_grant, //tcp tx
    output logic start,
    output logic [7:0] flags,
    output logic [15:0] tcp_length,
    output logic [15:0] payload_csum,
    input logic tx_done,
    output logic [7:0] payload_in_data, 
    output logic payload_in_valid,
    output logic payload_in_last, //last byte
    input logic payload_in_ready,
 
    //order signals from mm_core
    input logic quote_valid,
    input logic [63:0] bid_price, //PRICE9 mantissa (int64 * 10^-9)
    input logic [31:0] bid_size,
    input logic [63:0] ask_price,
    input logic [31:0] ask_size,
    input logic cancel_bid,
    input logic cancel_ask,
    input logic directional_valid,
    input logic directional_side, //0=buy 1=sell
    input logic [63:0] directional_price,
    input logic [31:0] directional_size,
 
    //exchange-assigned OrderIDs from ilink_rx (for cancel messages)
    //set to 0xFFFFFFFFFFFFFFFF if not yet received (OCR will use null OrderID)
    input logic [63:0] bid_order_id,
    input logic [63:0] ask_order_id
);



endmodule
