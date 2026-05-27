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
parameter [31:0] HB_INTERVAL = 32'd25_000_000, //heartbeat period in clock cycles (1s at 25MHz)
parameter [15:0] HB_INT_FIELD = 16'd10, //HeartBtInt value sent in Logon message (seconds)
parameter [63:0] SENDER_COMP_ID = 64'h0, //8-byte SenderCompID (ASCII LE packed)
parameter [63:0] PASSWORD = 64'h0, //8-byte logon password (ASCII LE packed)
parameter [63:0] SESSION_UUID = 64'h0 //64-bit session UUID for Logon UUID field
)(
    input logic clk,
    input logic rst,
 
    input logic established, //from tcp_session: connection is live
 
    //tcp_tx control interface (ilink_tx drives these only when tx_grant is high)
    input logic tx_grant,
    output logic start, //one-cycle pulse: tells tcp_tx to begin a segment
    output logic [7:0] flags, //TCP flags - always 0x18 (ACK+PSH) for data segments
    output logic [15:0] tcp_length, //TCP segment length = 20 (hdr) + payload bytes
    output logic [15:0] payload_csum, //one's complement sum of payload bytes for tcp_tx
    input logic tx_done, //one-cycle pulse from tcp_tx: segment fully sent
 
    //tcp_tx payload stream
    output logic [7:0] payload_in_data, //combinational byte from message buffer
    output logic payload_in_valid,
    output logic payload_in_last, //combinational last-byte flag
    input logic payload_in_ready, //from tcp_tx: byte was consumed this cycle
 
    //mm_core quote interface
    input logic quote_valid,
    input logic [63:0] bid_price, //PRICE9 format (integer * 1e-9)
    input logic [31:0] bid_size,
    input logic [63:0] ask_price,
    input logic [31:0] ask_size,
 
    //mm_core cancel interface
    input logic cancel_bid,
    input logic cancel_ask,
 
    //mm_core directional interface
    input logic directional_valid,
    input logic directional_side, //0=buy 1=sell
    input logic [63:0] directional_price,
    input logic [31:0] directional_size
);



endmodule
