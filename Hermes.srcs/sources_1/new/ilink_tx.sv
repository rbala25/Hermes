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
 

    input logic quote_valid,
    input logic [63:0] bid_price,
    input logic [31:0] bid_size,
    input logic [63:0] ask_price,
    input logic [31:0] ask_size,
    input logic cancel_bid,
    input logic cancel_ask,
    input logic directional_valid,
    input logic directional_side, //0=buy 1=sell
    input logic [63:0] directional_price,
    input logic [31:0] directional_size,
 
    input logic [63:0] bid_order_id,
    input logic [63:0] ask_order_id
);

typedef enum logic [2:0] {
    mtype_negotiate,
    mtype_establish,
    mtype_sequence,
    mtype_nos_bid,
    mtype_nos_ask,
    mtype_ocr_bid,
    mtype_ocr_ask,
    mtype_nos_dir
} mtype_t;
 
typedef enum logic [2:0] {
    s_idle,
    s_build,
    s_csum,
    s_wait_grant,
    s_tx,
    s_wait_done
} state_t;
 
state_t state;
mtype_t cur_msg;

localparam [7:0] NEG_LEN = 8'd90;
localparam [7:0] EST_LEN = 8'd146;
localparam [7:0] SEQ_LEN = 8'd26;
localparam [7:0] NOS_LEN = 8'd144;
localparam [7:0] OCR_LEN = 8'd108;

localparam [7:0] SCHEMA_LO = 8'd8; //v8
localparam [7:0] VERSION_LO = 8'd8;
 
localparam [63:0] PRICE_NULL = 64'h7FFFFFFFFFFFFFFF; //price9 null mantissa
localparam [63:0] U64_NULL = 64'hFFFFFFFFFFFFFFFF;
 
logic [7:0] msg_buf [0:255];
logic [7:0] msg_len; //byte count of current message
logic [7:0] build_cnt;
logic [7:0] tx_cnt;
logic [31:0] csum_accum;
 
logic [31:0] seq_num;
logic [31:0] cur_seq;
 
logic [31:0] hb_cnt;
logic established_prev;
 
logic neg_pending;
logic est_pending;
logic seq_pending;
logic nos_bid_pending;
logic nos_ask_pending;
logic ocr_bid_pending;
logic ocr_ask_pending;
logic nos_dir_pending;
 
logic [63:0] lat_bid_price;
logic [31:0] lat_bid_size;
logic [63:0] lat_ask_price;
logic [31:0] lat_ask_size;
logic [63:0] lat_dir_price;
logic [31:0] lat_dir_size;
logic lat_dir_side;
logic [63:0] lat_bid_order_id;
logic [63:0] lat_ask_order_id;

logic [31:0] lat_bid_clord_seq;
logic [31:0] lat_ask_clord_seq;
 
logic [16:0] csum_fold_w; //checksum helpers
logic [15:0] csum_final_w;
assign csum_fold_w = csum_accum[15:0] + csum_accum[31:16];
assign csum_final_w = csum_fold_w[15:0] + {15'h0, csum_fold_w[16]};
 
//----------------------------------------------------------------------
//combinational byte selection for build state
//All byte offsets match ilinkbinary_v8.xml field offsets exactly.
//Body bytes are at msg_buf offset = field_offset + 12 (SOFH + SBE header).
//----------------------------------------------------------------------
logic [7:0] cur_byte;



endmodule
