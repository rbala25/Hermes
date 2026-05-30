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

parameter [239:0] SYS_NAME = 240'h0, //all these are just placeholders lol
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

logic [63:0] nos_price_c; //newordersingle
logic [31:0] nos_qty_c;
logic [7:0]  nos_side_c;
logic [63:0] ocr_oid_c; //order cancel req
logic [7:0]  ocr_side_c;

assign nos_price_c = (cur_msg == mtype_nos_dir) ? lat_dir_price : (cur_msg == mtype_nos_bid) ? lat_bid_price : lat_ask_price;
assign nos_qty_c = (cur_msg == mtype_nos_dir) ? lat_dir_size : (cur_msg == mtype_nos_bid) ? lat_bid_size : lat_ask_size;
assign nos_side_c = (cur_msg == mtype_nos_dir) ? (lat_dir_side ? 8'd2 : 8'd1) : (cur_msg == mtype_nos_bid) ? 8'd1 : 8'd2;
assign ocr_oid_c = (cur_msg == mtype_ocr_bid) ? lat_bid_order_id : lat_ask_order_id;
assign ocr_side_c = (cur_msg == mtype_ocr_bid) ? 8'd1 : 8'd2;
 
logic [719:0] neg_vec; //90 bytes
logic [1167:0] est_vec; //146 bytes
logic [207:0] seq_vec; //26 bytes
logic [1151:0] nos_vec; //144 bytes
logic [863:0] ocr_vec; //108 bytes

logic [15:0] est_delay;
logic est_delay_done;
logic est_delay_done_prev;

always_ff @(posedge clk) begin
    if (rst) begin
        est_delay <= 0;
        est_delay_done <= 0;
    end else if (established && !established_prev) begin
        est_delay <= 0;
        est_delay_done <= 0;
    end else if (established && !est_delay_done) begin
        if (est_delay == 16'd25000) est_delay_done <= 1;
        else est_delay <= est_delay + 1;
    end else if (!established) begin
        est_delay_done <= 0;
    end
end

logic [7:0] cur_byte;
always_comb begin
    neg_vec = 0;
    neg_vec[95:0] = {8'h0,VERSION_LO, 8'h0,SCHEMA_LO, 8'h01,8'hF4, 8'h0,8'd76, 8'hCA,8'hFE, 8'h0,NEG_LEN};
    neg_vec[12*8 +: 256] = hmac_negotiate; //hmac sig
    neg_vec[44*8 +: 160] = ACCESS_KEY_ID; //access key id
    neg_vec[64*8 +: 64] = SESSION_UUID; //session uuid
    neg_vec[72*8 +: 64] = req_timestamp; //req timestamp
    neg_vec[80*8 +: 24] = SESSION_ID; //session id
    neg_vec[83*8 +: 40] = FIRM_ID; //firm id

    est_vec = 0;
    est_vec[95:0] = {8'h0,VERSION_LO,8'h0,SCHEMA_LO,8'h01,8'hF7,8'h0,8'd132,8'hCA,8'hFE,8'h0,EST_LEN};
    est_vec[12*8 +: 256] = hmac_establish; //hmac
    est_vec[44*8 +: 160] = ACCESS_KEY_ID;
    est_vec[64*8 +: 240] = SYS_NAME;
    est_vec[94*8 +: 80] = SYS_VERSION;
    est_vec[104*8 +: 80] = SYS_VENDOR;
    est_vec[114*8 +: 64] = SESSION_UUID;
    est_vec[122*8 +: 64] = req_timestamp;
    est_vec[130*8 +: 32] = seq_num;
    est_vec[134*8 +: 24] = SESSION_ID;
    est_vec[137*8 +: 40] = FIRM_ID;
    est_vec[142*8 +: 16] = KEEP_ALIVE_MS; //keep alive

    seq_vec = 0;
    seq_vec[95:0] = {8'h0,VERSION_LO,8'h0,SCHEMA_LO,8'h01,8'hFA,8'h0,8'd14,8'hCA,8'hFE,8'h0,SEQ_LEN};
    seq_vec[12*8 +: 64] = SESSION_UUID;
    seq_vec[20*8 +: 32] = seq_num;
    seq_vec[24*8 +: 8] = 8'h01; //primary

    nos_vec = 0;
    nos_vec[95:0] = {8'h0,VERSION_LO,8'h0,SCHEMA_LO,8'h02,8'h02,8'h0,8'd132,8'hCA,8'hFE,8'h0,NOS_LEN};
    nos_vec[12*8 +: 64] = nos_price_c; //price
    nos_vec[20*8 +: 32] = nos_qty_c; //qty
    nos_vec[24*8 +: 32] = SECURITY_ID;
    nos_vec[28*8 +: 8] = nos_side_c; //side
    nos_vec[29*8 +: 32] = cur_seq;
    nos_vec[33*8 +: 160] = SENDER_ID;
    nos_vec[53*8 +: 32] = cur_seq;
    nos_vec[73*8 +: 64] = PARTY_DETAILS_REQ_ID;
    nos_vec[81*8 +: 32] = cur_seq;
    nos_vec[97*8 +: 64] = PRICE_NULL;
    nos_vec[105*8 +: 40] = LOCATION;
    nos_vec[110*8 +: 32] = 32'hFFFFFFFF;
    nos_vec[114*8 +: 32] = 32'hFFFFFFFF;
    nos_vec[118*8 +: 16] = 16'hFFFF;
    nos_vec[120*8 +: 8] = 8'h32;
    nos_vec[121*8 +: 8] = 8'h01;
    nos_vec[125*8 +: 8] = 8'hFF;
    nos_vec[126*8 +: 8] = 8'hFF;
    nos_vec[128*8 +: 64] = PRICE_NULL;
    nos_vec[136*8 +: 64] = PRICE_NULL;

    ocr_vec = 0;
    ocr_vec[95:0] = {8'h0,VERSION_LO,8'h0,SCHEMA_LO,8'h02,8'h04,8'h0,8'd96,8'hCA,8'hFE,8'h0,OCR_LEN};
    ocr_vec[12*8 +: 64] = ocr_oid_c; //order id
    ocr_vec[20*8 +: 64] = PARTY_DETAILS_REQ_ID;
    ocr_vec[29*8 +: 32] = cur_seq;
    ocr_vec[33*8 +: 160] = SENDER_ID;
    ocr_vec[53*8 +: 32] = cur_seq;
    ocr_vec[73*8 +: 32] = cur_seq;
    ocr_vec[89*8 +: 40] = LOCATION;
    ocr_vec[94*8 +: 32] = SECURITY_ID;
    ocr_vec[98*8 +: 8] = ocr_side_c;
    ocr_vec[99*8 +: 8] = 8'hFF;

    case(cur_msg)
        mtype_negotiate: cur_byte = neg_vec[{build_cnt,3'b0} +: 8];
        mtype_establish: cur_byte = est_vec[{build_cnt,3'b0} +: 8];
        mtype_sequence: cur_byte = seq_vec[{build_cnt,3'b0} +: 8];
        mtype_nos_bid, mtype_nos_ask, mtype_nos_dir: cur_byte = nos_vec[{build_cnt,3'b0} +: 8];
        mtype_ocr_bid, mtype_ocr_ask: cur_byte = ocr_vec[{build_cnt,3'b0} +: 8];
        default: cur_byte = 8'd0;
    endcase
end

logic [7:0] next_tx_cnt;
assign next_tx_cnt = (payload_in_ready && state == s_tx && tx_cnt != msg_len - 8'd1) ? tx_cnt + 8'd1 : tx_cnt;
assign payload_in_last = (state == s_tx) && (tx_cnt == msg_len - 8'd1);
assign payload_in_data = msg_buf[next_tx_cnt]; //putting bytes on wire
//assign payload_in_last = (state == s_tx) && (next_tx_cnt == msg_len - 8'd1);
 
assign flags = 8'h18; //always 0x18 (ack and psh) for data

always_ff @(posedge clk) begin
    if (rst) begin
        state <= s_idle;
        cur_msg <= mtype_sequence;
        seq_num <= 32'd1;
        cur_seq <= 0;
        build_cnt <= 0;
        tx_cnt <= 0;
        csum_accum <= 0;
        msg_len <= 0;
        hb_cnt <= 0;
        established_prev <= 0;
        ilink_established <= 0;
        neg_pending <= 0;
        est_pending <= 0;
        seq_pending <= 0;
        nos_bid_pending <= 0;
        nos_ask_pending <= 0;
        ocr_bid_pending <= 0;
        ocr_ask_pending <= 0;
        nos_dir_pending <= 0;
        lat_bid_price <= 0;
        lat_bid_size <= 0;
        lat_ask_price <= 0;
        lat_ask_size <= 0;
        lat_dir_price <= 0;
        lat_dir_size <= 0;
        lat_dir_side <= 0;
        lat_bid_order_id <= {64{1'b1}}; //null
        lat_ask_order_id <= {64{1'b1}}; 
        lat_bid_clord_seq <= 0;
        lat_ask_clord_seq <= 0;
        tcp_length <= 0;
        payload_csum <= 0;
        payload_in_valid <= 0;
        est_delay_done_prev <= 0;
        start <= 0;
        for (int i = 0; i < 256; i++) msg_buf[i] <= 0;
    end else begin
        start <= 0; 
        
        established_prev <= established;
        est_delay_done_prev <= est_delay_done;
        if (est_delay_done && !est_delay_done_prev) begin
            neg_pending <= 1;
            seq_num <= 32'd1;
            ilink_established <= 0;
            hb_cnt <= 0;
        end 
        
        if (!established && state != s_idle) begin
            state <= s_idle;
            payload_in_valid <= 0;
            neg_pending <= 0;
            est_pending <= 0;
        end
        
        if (neg_response) est_pending <= 1; 
        if (estab_ack) begin //neg establish ack
            ilink_established <= 1;
            hb_cnt <= 0;
        end
 
        if (!established) begin
            ilink_established <= 0;
            neg_pending <= 0; //end tcp session
            est_pending <= 0;
        end
        
        if (ilink_established) begin //look at this agaun (IMPORTANT)
            if (quote_valid) begin //latch
                lat_bid_price <= bid_price;
                lat_bid_size <= bid_size;
                lat_ask_price <= ask_price;
                lat_ask_size <= ask_size;
                nos_bid_pending <= 1;
                nos_ask_pending <= 1;
            end
            if (cancel_bid) begin
                lat_bid_order_id <= bid_order_id;
                ocr_bid_pending <= 1;
            end
            if (cancel_ask) begin
                lat_ask_order_id <= ask_order_id;
                ocr_ask_pending <= 1;
            end
            if (directional_valid) begin
                lat_dir_price <= directional_price;
                lat_dir_size <= directional_size;
                lat_dir_side <= directional_side;
                nos_dir_pending <= 1;
            end
        end
        
        if (!ilink_established) begin
            hb_cnt <= 0;
            seq_pending <= 0;
        end else begin //seq keep alive
            if (hb_cnt == HB_INTERVAL - 32'd1) begin
                hb_cnt <= 0;
                seq_pending <= 1;
            end else begin
                hb_cnt <= hb_cnt + 32'd1;
            end
        end
        
        unique case (state)
            s_idle: begin
                payload_in_valid <= 0; //negotiate > establish > ocr > nos > directional > sequence
                if (neg_pending) begin
                    neg_pending <= 0;
                    cur_msg <= mtype_negotiate;
                    msg_len <= NEG_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end else if (est_pending) begin
                    est_pending <= 0;
                    cur_msg <= mtype_establish;
                    msg_len <= EST_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0; //no increment of seq
                    state <= s_build;
                end else if (ocr_bid_pending) begin
                    ocr_bid_pending <= 0;
                    cur_msg <= mtype_ocr_bid;
                    cur_seq <= seq_num;
                    seq_num <= seq_num + 32'd1;
                    msg_len <= OCR_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end else if (ocr_ask_pending) begin
                    ocr_ask_pending <= 0;
                    cur_msg <= mtype_ocr_ask;
                    cur_seq <= seq_num;
                    seq_num <= seq_num + 32'd1;
                    msg_len <= OCR_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end else if (nos_bid_pending) begin
                    nos_bid_pending <= 0;
                    lat_bid_clord_seq <= seq_num;
                    cur_msg <= mtype_nos_bid;
                    cur_seq <= seq_num;
                    seq_num <= seq_num + 32'd1;
                    msg_len <= NOS_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end else if (nos_ask_pending) begin
                    nos_ask_pending <= 0;
                    lat_ask_clord_seq <= seq_num;
                    cur_msg <= mtype_nos_ask;
                    cur_seq <= seq_num;
                    seq_num <= seq_num + 32'd1;
                    msg_len <= NOS_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end else if (nos_dir_pending) begin
                    nos_dir_pending <= 0;
                    cur_msg <= mtype_nos_dir;
                    cur_seq <= seq_num;
                    seq_num <= seq_num + 32'd1;
                    msg_len <= NOS_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end else if (seq_pending) begin
                    seq_pending <= 0;
                    cur_msg <= mtype_sequence;
                    msg_len <= SEQ_LEN;
                    build_cnt <= 0;
                    csum_accum <= 0;
                    state <= s_build;
                end
            end
            
            s_build: begin
                msg_buf[build_cnt] <= cur_byte;
                if (!build_cnt[0]) //high byte for even
                    csum_accum <= csum_accum + {16'h0, cur_byte, 8'h0};
                else //low byte for odd
                    csum_accum <= csum_accum + {24'h0, cur_byte};
                if (build_cnt == msg_len - 8'd1) begin
                    build_cnt <= 0;
                    state <= s_csum;
                end else begin
                    build_cnt <= build_cnt + 8'd1;
                end
            end
            
            s_csum: begin
                payload_csum <= csum_final_w;
                tcp_length <= 16'd20 + {8'h0, msg_len};
                state <= s_wait_grant;
            end
            
            s_wait_grant: begin
                if (tx_grant) begin
                    start <= 1;
                    tx_cnt <= 0;
                    payload_in_valid <= 1;
                    state <= s_tx;
                end
            end
            
            s_tx: begin
                if (payload_in_ready) begin //bytes get streamed via combinational logic way above
                    if (tx_cnt == msg_len - 8'd1) begin
                        payload_in_valid <= 0;
                        state <= s_wait_done;
                    end else begin
                        tx_cnt <= tx_cnt + 8'd1;
                    end
                end
            end
            
            s_wait_done: begin
                if (tx_done) begin
                    state <= s_idle;
                    if (cur_msg == mtype_negotiate) est_pending <= 1;
                end
            end 
            
            default: state <= s_idle;
        endcase
    end
end
endmodule
