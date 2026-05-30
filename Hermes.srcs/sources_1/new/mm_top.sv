`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/28/2026 12:25:43 AM
// Design Name: 
// Module Name: mm_top
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


module mm_top #(
    parameter logic [47:0] MY_MAC = 48'h00183E03E41B,
    parameter logic [31:0] MY_IP = 32'hC0A80164,
    parameter logic [31:0] CME_IP = 32'hC0A80102,
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
    parameter logic [31:0] KEEPALIVE_CYCLES = 32'd125000000,
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
    output logic [3:0] led,
    
    input logic clk_100,
    output logic eth_ref_clk,
    output logic eth_rstn,
    
    output logic eth_mdc,
    output logic eth_mdio   
);
 
logic locked;
clk_gen u_clk_gen (
    .clk_100(clk_100),
    .clk_25(eth_ref_clk),
    .locked(locked)
);
 
logic [19:0] rst_cnt;
logic phy_rstn;
always_ff @(posedge clk_100) begin
    if (!locked) begin
        rst_cnt <= 0;
        phy_rstn <= 0;
    end else if (!phy_rstn) begin
        rst_cnt <= rst_cnt + 1;
        if (rst_cnt == 20'hFFFFF) phy_rstn <= 1;
    end
end
assign eth_rstn = phy_rstn;
 
logic rst_sync_tx_0, rst_sync_tx;
logic rst_sync_rx_0, rst_sync_rx;
always_ff @(posedge tx_clk) begin
    rst_sync_tx_0 <= rst || !locked;
    rst_sync_tx <= rst_sync_tx_0;
end
always_ff @(posedge rx_clk) begin
    rst_sync_rx_0 <= rst || !locked;
    rst_sync_rx <= rst_sync_rx_0;
end
 
logic link_ready;
 
logic [7:0] mii_rx_data; //mii rx outputs
logic mii_rx_valid;
logic mii_rx_frame_active;
 
logic [47:0] eth_dest_mac; //eth parser outputs
logic [47:0] eth_src_mac;
logic [15:0] eth_ether_type;
logic eth_header_valid;
logic [7:0] eth_payload_data;
logic eth_payload_valid;
logic eth_frame_done;
logic eth_error;
 
logic [3:0] ip_version; //ip parser outputs
logic [3:0] ip_ihl;
logic [7:0] ip_dscp;
logic [15:0] ip_total_len;
logic [15:0] ip_id;
logic [2:0] ip_flags;
logic [12:0] ip_frag_offset;
logic [7:0] ip_ttl;
logic [7:0] ip_protocol;
logic [15:0] ip_checksum;
logic [31:0] ip_src;
logic [31:0] ip_dest;
logic ip_header_valid;
logic ip_checksum_val;
logic ip_is_fragment;
logic [7:0] ip_payload_data;
logic ip_payload_valid;
logic ip_payload_done;
logic ip_error;
 
logic [15:0] udp_src; //udp parser outputs
logic [15:0] udp_dest;
logic [15:0] udp_length;
logic [15:0] udp_checksum;
logic udp_header_valid;
logic udp_checksum_val;
logic [7:0] udp_payload;
logic udp_payload_valid;
logic udp_payload_done;
logic udp_error;
 
logic [31:0] mdp_seq_num; //mdp parser outputs
logic [63:0] mdp_sending_time;
logic mdp_pkt_valid;
logic [63:0] mdp_entry_price;
logic [31:0] mdp_entry_size;
logic [7:0] mdp_entry_price_level;
logic [7:0] mdp_entry_update_action;
logic [7:0] mdp_entry_type;
logic mdp_is_snapshot;
logic mdp_entry_valid;
logic mdp_done;
logic mdp_error;
logic [63:0] mdp_trade_price;
logic [31:0] mdp_trade_size;
logic [1:0] mdp_trade_aggressor;
logic mdp_trade_valid;
 
logic [63:0] ob_best_bid_price; //order book outputs
logic [31:0] ob_best_bid_size;
logic [63:0] ob_best_ask_price;
logic [31:0] ob_best_ask_size;
logic ob_book_valid;
logic ob_gap_detected;
logic [3:0] ob_rd_level;
logic ob_rd_side;
logic [63:0] ob_rd_price;
logic [31:0] ob_rd_size;
 
logic tcprx_data_in_ready; //tcp rx outputs
logic [15:0] tcprx_src_port;
logic [15:0] tcprx_dst_port;
logic [31:0] tcprx_seq_num;
logic [31:0] tcprx_ack_num;
logic [7:0] tcprx_flags;
logic [15:0] tcprx_window_size;
logic tcprx_header_valid;
logic [7:0] tcprx_payload_data;
logic tcprx_payload_valid;
logic tcprx_payload_ready;
logic tcprx_rx_syn;
logic tcprx_rx_ack;
logic tcprx_rx_fin;
logic tcprx_rx_rst;
logic tcprx_csum_error;
 
logic [15:0] tcp_segment_length;
assign tcp_segment_length = ip_total_len - {10'b0, ip_ihl, 2'b00};
 
logic tcp_ip_payload_valid;
assign tcp_ip_payload_valid = ip_payload_valid && (ip_protocol == 8'h06);
 
logic tcp_ip_payload_done_rx;
assign tcp_ip_payload_done_rx = ip_payload_done && (ip_protocol == 8'h06);
 
logic [7:0] icmp_type; //icmp parser outputs
logic [7:0] icmp_code;
logic [15:0] icmp_checksum_rx;
logic [15:0] icmp_identifier;
logic [15:0] icmp_seq_num;
logic icmp_header_valid;
logic icmp_checksum_val;
logic [7:0] icmp_payload_data;
logic icmp_payload_valid;
logic icmp_payload_done;
logic icmp_error;
 
logic [47:0] rep_dst_mac; //icmp reply params latched on ping arrival
logic [31:0] rep_dst_ip;
logic [15:0] rep_identifier;
logic [15:0] rep_seq;
logic [15:0] rep_total_len;
logic [15:0] rep_ip_id;
logic [15:0] rep_icmp_checksum_rx;
 
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) begin
        rep_dst_mac <= 0;
        rep_dst_ip <= 0;
        rep_identifier <= 0;
        rep_seq <= 0;
        rep_total_len <= 0;
        rep_ip_id <= 0;
        rep_icmp_checksum_rx <= 0;
    end else if (icmp_header_valid && icmp_type == 8'h08 && icmp_code == 8'h00) begin
        rep_dst_mac <= eth_src_mac;
        rep_dst_ip <= ip_src;
        rep_identifier <= icmp_identifier;
        rep_seq <= icmp_seq_num;
        rep_total_len <= ip_total_len;
        rep_ip_id <= ip_id;
        rep_icmp_checksum_rx <= icmp_checksum_rx;
    end
end
 
localparam ICMP_FIFO_DEPTH = 256;
localparam ICMP_FIFO_AW = $clog2(ICMP_FIFO_DEPTH);
logic [7:0] icmp_fifo_mem [0:ICMP_FIFO_DEPTH-1];
logic [ICMP_FIFO_AW-1:0] icmp_fifo_wr_ptr;
logic [ICMP_FIFO_AW-1:0] icmp_fifo_rd_ptr;
 
logic [ICMP_FIFO_AW-1:0] icmp_wr_snap_meta, icmp_wr_snap_tx;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        icmp_wr_snap_meta <= 0;
        icmp_wr_snap_tx <= 0;
    end else begin
        icmp_wr_snap_meta <= icmp_fifo_wr_ptr;
        icmp_wr_snap_tx <= icmp_wr_snap_meta;
    end
end
 
logic icmp_fifo_valid_tx;
logic icmp_fifo_ready;
assign icmp_fifo_valid_tx = (icmp_fifo_rd_ptr != icmp_wr_snap_tx);
 
logic icmp_fifo_rst_wr;
logic icmp_fifo_rst_meta, icmp_fifo_rst_tx, icmp_fifo_rst_tx_r;
 
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) icmp_fifo_rst_wr <= 0;
    else icmp_fifo_rst_wr <= (icmp_header_valid && icmp_type == 8'h08 && icmp_code == 8'h00);
end
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        icmp_fifo_rst_meta <= 0;
        icmp_fifo_rst_tx <= 0;
        icmp_fifo_rst_tx_r <= 0;
    end else begin
        icmp_fifo_rst_meta <= icmp_fifo_rst_wr;
        icmp_fifo_rst_tx <= icmp_fifo_rst_meta;
        icmp_fifo_rst_tx_r <= icmp_fifo_rst_tx;
    end
end
 
logic icmp_fifo_rd_rst;
assign icmp_fifo_rd_rst = icmp_fifo_rst_tx && !icmp_fifo_rst_tx_r;
 
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) icmp_fifo_wr_ptr <= 0;
    else if (icmp_header_valid && icmp_type == 8'h08 && icmp_code == 8'h00) icmp_fifo_wr_ptr <= 0;
    else if (icmp_payload_valid) begin
        icmp_fifo_mem[icmp_fifo_wr_ptr] <= icmp_payload_data;
        icmp_fifo_wr_ptr <= icmp_fifo_wr_ptr + 1;
    end
end
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) icmp_fifo_rd_ptr <= 0;
    else if (icmp_fifo_rd_rst) icmp_fifo_rd_ptr <= 0;
    else if (icmp_fifo_valid_tx && icmp_fifo_ready) icmp_fifo_rd_ptr <= icmp_fifo_rd_ptr + 1;
end
 
logic [7:0] ictx_data; //icmp tx to ip tx
logic ictx_valid;
logic ictx_ready;
logic icmp_tx_done;
logic [15:0] icmp_checksum_tx;
 
logic ilrx_payload_ready; //ilink rx outputs
logic ilrx_neg_response;
logic ilrx_estab_ack;
logic ilrx_session_error;
logic [383:0] ilrx_reject_reason;
logic [31:0] ilrx_next_seq_no;
logic [31:0] ilrx_rx_next_seq_no;
logic ilrx_send_sequence;
logic [63:0] ilrx_bid_order_id;
logic [63:0] ilrx_ask_order_id;
logic ilrx_exec_new;
logic ilrx_exec_reject;
logic ilrx_exec_elimination;
logic ilrx_exec_trade;
logic ilrx_exec_modify;
logic ilrx_exec_cancel;
logic ilrx_unsolicited_cancel;
logic ilrx_ocr_reject;
logic ilrx_business_reject;
logic ilrx_gap_detected;
logic [31:0] ilrx_gap_from_seq;
logic [31:0] ilrx_gap_count;
logic signed [63:0] ilrx_fill_price;
logic [31:0] ilrx_fill_qty;
logic [31:0] ilrx_fill_leaves_qty;
logic [31:0] ilrx_fill_cum_qty;
logic [7:0] ilrx_fill_side;
logic [159:0] ilrx_fill_clord_id;
logic [319:0] ilrx_exec_id;
logic [15:0] ilrx_ord_rej_reason;
logic [15:0] ilrx_cxl_rej_reason;
logic [63:0] ilrx_order_id_out;
logic [15:0] ilrx_biz_rej_reason;
logic [2047:0] ilrx_biz_text;
 
localparam MD2_FIFO_DEPTH = 16;
localparam MD2_FIFO_AW = $clog2(MD2_FIFO_DEPTH);
localparam MD2_WIDTH = 292;
 
logic [MD2_WIDTH-1:0] md2_fifo_mem [0:MD2_FIFO_DEPTH-1];
logic [MD2_FIFO_AW-1:0] md2_wr_ptr;
logic [MD2_FIFO_AW-1:0] md2_rd_ptr;
 
logic [MD2_FIFO_AW-1:0] md2_wr_ptr_meta, md2_wr_ptr_tx;
always_ff @(posedge tx_clk) begin //metastability
    if (rst_sync_tx) begin
        md2_wr_ptr_meta <= 0;
        md2_wr_ptr_tx <= 0;
    end else begin
        md2_wr_ptr_meta <= md2_wr_ptr;
        md2_wr_ptr_tx <= md2_wr_ptr_meta;
    end
end
 
logic md2_fifo_not_empty;
assign md2_fifo_not_empty = (md2_rd_ptr != md2_wr_ptr_tx);
 
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) begin
        md2_wr_ptr <= 0;
    end else if (ob_book_valid && (mdp_entry_valid || mdp_trade_valid)) begin //check condition
        md2_fifo_mem[md2_wr_ptr] <= {
            ob_book_valid,
            ob_best_bid_price,
            ob_best_bid_size,
            ob_best_ask_price,
            ob_best_ask_size,
            mdp_trade_valid,
            mdp_trade_price,
            mdp_trade_size,
            mdp_trade_aggressor
        };
        md2_wr_ptr <= md2_wr_ptr + 1;
    end
end
 
logic [MD2_WIDTH-1:0] md2_fifo_rdata;
assign md2_fifo_rdata = md2_fifo_mem[md2_rd_ptr];
 
logic [63:0] mm_best_bid_price_w;
logic [31:0] mm_best_bid_size_w;
logic [63:0] mm_best_ask_price_w;
logic [31:0] mm_best_ask_size_w;
logic mm_book_valid_w;
logic mm_trade_valid_w;
logic [63:0] mm_trade_price_w;
logic [31:0] mm_trade_size_w;
logic [1:0] mm_trade_aggressor_w;
 
assign {mm_book_valid_w, mm_best_bid_price_w, mm_best_bid_size_w, mm_best_ask_price_w, mm_best_ask_size_w,
        mm_trade_valid_w, mm_trade_price_w, mm_trade_size_w, mm_trade_aggressor_w} = md2_fifo_rdata;
 
logic mm_book_valid_r;
logic [63:0] mm_best_bid_price_r;
logic [31:0] mm_best_bid_size_r;
logic [63:0] mm_best_ask_price_r;
logic [31:0] mm_best_ask_size_r;
logic mm_trade_valid_r;
logic [63:0] mm_trade_price_r;
logic [31:0] mm_trade_size_r;
logic [1:0] mm_trade_aggressor_r;
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        md2_rd_ptr <= 0;
        mm_book_valid_r <= 0;
        mm_best_bid_price_r <= 0;
        mm_best_bid_size_r <= 0;
        mm_best_ask_price_r <= 0;
        mm_best_ask_size_r <= 0;
        mm_trade_valid_r <= 0;
        mm_trade_price_r <= 0;
        mm_trade_size_r <= 0;
        mm_trade_aggressor_r <= 0;
    end else if (md2_fifo_not_empty) begin
        mm_book_valid_r <= mm_book_valid_w;
        mm_best_bid_price_r <= mm_best_bid_price_w;
        mm_best_bid_size_r <= mm_best_bid_size_w;
        mm_best_ask_price_r <= mm_best_ask_price_w;
        mm_best_ask_size_r <= mm_best_ask_size_w;
        mm_trade_valid_r <= mm_trade_valid_w;
        mm_trade_price_r <= mm_trade_price_w;
        mm_trade_size_r <= mm_trade_size_w;
        mm_trade_aggressor_r <= mm_trade_aggressor_w;
        md2_rd_ptr <= md2_rd_ptr + 1;
    end else begin
        mm_book_valid_r <= 0;
        mm_trade_valid_r <= 0;
    end
end
 
localparam FILL_FIFO_DEPTH = 16;
localparam FILL_FIFO_AW = $clog2(FILL_FIFO_DEPTH);
localparam FILL_WIDTH = 105;
 
logic [FILL_WIDTH-1:0] fill_fifo_mem [0:FILL_FIFO_DEPTH-1];
logic [FILL_FIFO_AW-1:0] fill_wr_ptr;
logic [FILL_FIFO_AW-1:0] fill_rd_ptr;
 
logic [FILL_FIFO_AW-1:0] fill_wr_ptr_meta, fill_wr_ptr_tx;
always_ff @(posedge tx_clk) begin //same thing lol
    if (rst_sync_tx) begin
        fill_wr_ptr_meta <= 0;
        fill_wr_ptr_tx <= 0;
    end else begin
        fill_wr_ptr_meta <= fill_wr_ptr;
        fill_wr_ptr_tx <= fill_wr_ptr_meta;
    end
end
 
logic fill_fifo_not_empty;
assign fill_fifo_not_empty = (fill_rd_ptr != fill_wr_ptr_tx);
 
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) begin
        fill_wr_ptr <= 0;
    end else if (ilrx_exec_trade) begin
        fill_fifo_mem[fill_wr_ptr] <= {
            ilrx_exec_trade,
            ilrx_fill_price,
            ilrx_fill_qty,
            ilrx_fill_side
        };
        fill_wr_ptr <= fill_wr_ptr + 1;
    end
end
 
logic [FILL_WIDTH-1:0] fill_fifo_rdata;
assign fill_fifo_rdata = fill_fifo_mem[fill_rd_ptr];
 
logic fill_valid_bit_w;
logic [63:0] fill_price_w;
logic [31:0] fill_qty_w;
logic [7:0] fill_side_w;
assign {fill_valid_bit_w, fill_price_w, fill_qty_w, fill_side_w} = fill_fifo_rdata;
 
logic mm_fill_valid;
logic [63:0] mm_fill_price;
logic [31:0] mm_fill_size;
logic mm_fill_side;
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        fill_rd_ptr <= 0;
        mm_fill_valid <= 0;
        mm_fill_price <= 0;
        mm_fill_size <= 0;
        mm_fill_side <= 0;
    end else if (fill_fifo_not_empty) begin
        mm_fill_valid <= fill_valid_bit_w;
        mm_fill_price <= fill_price_w;
        mm_fill_size <= fill_qty_w;
        mm_fill_side <= fill_side_w[0];
        fill_rd_ptr <= fill_rd_ptr + 1;
    end else begin
        mm_fill_valid <= 0;
    end
end
 
logic neg_response_meta, neg_response_tx; //synchronizing response pulses for ilink tx
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        neg_response_meta <= 0;
        neg_response_tx <= 0;
    end else begin
        neg_response_meta <= ilrx_neg_response;
        neg_response_tx <= neg_response_meta;
    end
end
 
logic estab_ack_meta, estab_ack_tx; //estab_ack pulse sync
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        estab_ack_meta <= 0;
        estab_ack_tx <= 0;
    end else begin
        estab_ack_meta <= ilrx_estab_ack;
        estab_ack_tx <= estab_ack_meta;
    end
end
 
logic send_sequence_meta, send_sequence_tx;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        send_sequence_meta <= 0;
        send_sequence_tx <= 0;
    end else begin
        send_sequence_meta <= ilrx_send_sequence;
        send_sequence_tx <= send_sequence_meta;
    end
end
 
logic [63:0] bid_order_id_meta, bid_order_id_tx;
logic [63:0] ask_order_id_meta, ask_order_id_tx;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        bid_order_id_meta <= 0;
        bid_order_id_tx <= 0;
        ask_order_id_meta <= 0;
        ask_order_id_tx <= 0;
    end else begin
        bid_order_id_meta <= ilrx_bid_order_id;
        bid_order_id_tx <= bid_order_id_meta;
        ask_order_id_meta <= ilrx_ask_order_id;
        ask_order_id_tx <= ask_order_id_meta;
    end
end
 
logic session_error_meta, session_error_tx;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        session_error_meta <= 0;
        session_error_tx <= 0;
    end else begin
        session_error_meta <= ilrx_session_error;
        session_error_tx <= session_error_meta;
    end
end
 
logic [63:0] mm_bid_price; //mm core
logic [31:0] mm_bid_size;
logic [63:0] mm_ask_price;
logic [31:0] mm_ask_size;
logic mm_quote_valid;
logic mm_cancel_bid;
logic mm_cancel_ask;
logic mm_risk_breach;
logic mm_directional_valid;
logic mm_directional_side;
logic [63:0] mm_directional_price;
logic [31:0] mm_directional_size;
logic [3:0] mm_rd_level;
logic mm_rd_side;
 
assign ob_rd_level = mm_rd_level; //is rd port cdc????? *
assign ob_rd_side = mm_rd_side;
 
logic iltx_ilink_established; //ilink tx
logic iltx_start;
logic [7:0] iltx_flags;
logic [15:0] iltx_tcp_length;
logic [15:0] iltx_payload_csum;
logic [7:0] iltx_payload_data;
logic iltx_payload_valid;
logic iltx_payload_last;
logic iltx_payload_ready;
 
logic sess_ctrl_start; //tcp session
logic [7:0] sess_ctrl_flags;
logic [31:0] sess_ctrl_ack_num;
logic [15:0] sess_ctrl_tcp_length;
logic [15:0] sess_ctrl_payload_csum;
logic sess_load_seq;
logic [31:0] sess_init_seq;
logic sess_tx_grant;
logic sess_established;
logic sess_closed;
 
logic rx_syn_lat, rx_ack_lat, rx_fin_lat, rx_rst_lat;
logic [31:0] rx_seq_lat;
logic rx_hv_toggle;
 
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) begin
        rx_syn_lat <= 0;
        rx_ack_lat <= 0;
        rx_fin_lat <= 0;
        rx_rst_lat <= 0;
        rx_seq_lat <= 0;
        rx_hv_toggle <= 0;
    end else if (tcprx_header_valid) begin
        rx_syn_lat <= tcprx_rx_syn;
        rx_ack_lat <= tcprx_rx_ack;
        rx_fin_lat <= tcprx_rx_fin;
        rx_rst_lat <= tcprx_rx_rst;
        rx_seq_lat <= tcprx_seq_num;
        rx_hv_toggle <= ~rx_hv_toggle;
    end
end
 
logic rx_hv_tog_meta, rx_hv_tog_tx, rx_hv_tog_tx_r;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        rx_hv_tog_meta <= 0;
        rx_hv_tog_tx <= 0;
        rx_hv_tog_tx_r <= 0;
    end else begin
        rx_hv_tog_meta <= rx_hv_toggle;
        rx_hv_tog_tx <= rx_hv_tog_meta;
        rx_hv_tog_tx_r <= rx_hv_tog_tx;
    end
end
 
logic tcprx_hv_tx;
logic tcprx_syn_tx;
logic tcprx_ack_tx;
logic tcprx_fin_tx;
logic tcprx_rst_tx;
logic [31:0] tcprx_seq_tx;
 
assign tcprx_hv_tx = rx_hv_tog_tx ^ rx_hv_tog_tx_r;
assign tcprx_syn_tx = rx_syn_lat;
assign tcprx_ack_tx = rx_ack_lat;
assign tcprx_fin_tx = rx_fin_lat;
assign tcprx_rst_tx = rx_rst_lat;
assign tcprx_seq_tx = rx_seq_lat;
 
logic [7:0] tcptx_payload_data; //tcp tx to ip tx
logic tcptx_payload_valid;
logic tcptx_payload_ready;
logic tcptx_done;
 
logic sess_ctrl_start_lat;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) sess_ctrl_start_lat <= 0;
    else if (sess_ctrl_start) sess_ctrl_start_lat <= 1;
    else if (ethtx_start && tx_is_tcp) sess_ctrl_start_lat <= 0;
end
 
logic tcp_start_mux; //mux for ilink and tcp session
logic [7:0] tcp_flags_mux;
logic [15:0] tcp_length_mux;
logic [15:0] tcp_payload_csum_mux;
logic [31:0] tcp_ack_num_mux;
 
assign tcp_start_mux = (sess_ctrl_start || sess_ctrl_start_lat) ? 1'b1 : iltx_start;
assign tcp_flags_mux = (sess_ctrl_start || sess_ctrl_start_lat) ? sess_ctrl_flags : iltx_flags;
assign tcp_length_mux = (sess_ctrl_start || sess_ctrl_start_lat) ? sess_ctrl_tcp_length : iltx_tcp_length;
assign tcp_payload_csum_mux = (sess_ctrl_start || sess_ctrl_start_lat) ? sess_ctrl_payload_csum : iltx_payload_csum;
assign tcp_ack_num_mux = (sess_ctrl_start || sess_ctrl_start_lat) ? sess_ctrl_ack_num : 32'h0;
 
assign iltx_payload_ready = sess_ctrl_start ? 1'b0 : tcptx_payload_ready; //tcp session gets priority
logic [7:0] tcp_pld_data_mux;
logic tcp_pld_valid_mux;
logic tcp_pld_last_mux;
assign tcp_pld_data_mux = sess_ctrl_start ? 8'h0 : iltx_payload_data;
assign tcp_pld_valid_mux = sess_ctrl_start ? 1'b0 : iltx_payload_valid;
assign tcp_pld_last_mux = sess_ctrl_start ? 1'b0 : iltx_payload_last;
 
logic [7:0] iptx_data; //ip tx to eth tx
logic iptx_valid;
logic iptx_ready;
logic iptx_start;
logic iptx_done;
 
logic [7:0] ethtx_data; //eth tx to mii tx
logic ethtx_valid;
logic ethtx_ready;
logic ethtx_done;
logic ethtx_start;
 
logic [47:0] arp_reply_dst_mac;
logic arp_pending;
logic arp_start;
logic arp_done;
logic [7:0] arp_payload_data;
logic arp_payload_valid;
logic arp_payload_ready;
 
logic tx_is_arp;
logic tx_is_tcp;
 
logic [47:0] gateway_mac;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) gateway_mac <= 0;
    else if (arp_pending && arp_reply_dst_mac != 0) gateway_mac <= arp_reply_dst_mac;
end
 
logic [47:0] mux_dst_mac;
logic [15:0] mux_ether_type;
logic [7:0] mux_payload_data;
logic mux_payload_valid;
logic mux_payload_ready;
 
//assign mux_dst_mac = tx_is_arp ? arp_reply_dst_mac : rep_dst_mac;
assign mux_dst_mac = tx_is_arp ? arp_reply_dst_mac : tx_is_tcp ? gateway_mac : rep_dst_mac;
assign mux_ether_type = tx_is_arp ? 16'h0806 : 16'h0800;
assign mux_payload_data = tx_is_arp ? arp_payload_data : iptx_data;
assign mux_payload_valid = tx_is_arp ? arp_payload_valid : iptx_valid;
assign iptx_ready = tx_is_arp ? 1'b0 : mux_payload_ready;
assign arp_payload_ready = tx_is_arp ? mux_payload_ready : 1'b0;
 
logic [7:0] ip_payload_mux_data;
logic ip_payload_mux_valid;
logic ip_payload_mux_ready;
 
assign ip_payload_mux_data = tx_is_tcp ? tcptx_payload_data : ictx_data;
assign ip_payload_mux_valid = tx_is_tcp ? tcptx_payload_valid : ictx_valid;
assign ictx_ready = tx_is_tcp ? 1'b0 : ip_payload_mux_ready;
 
logic [31:0] ip_dst_mux;
logic [7:0] ip_protocol_mux;
logic [15:0] ip_total_len_mux;
logic [15:0] ip_id_mux;
 
assign ip_dst_mux = tx_is_tcp ? CME_IP : rep_dst_ip;
assign ip_protocol_mux = tx_is_tcp ? 8'h06 : 8'h01;
assign ip_total_len_mux = tx_is_tcp ? tcp_length_mux : rep_total_len;
assign ip_id_mux = tx_is_tcp ? 16'h0 : rep_ip_id;
 
assign iptx_start = ethtx_start && !tx_is_arp;
 
typedef enum logic [1:0] {
    TX_IDLE,
    TX_WAIT
} tx_state_t;
tx_state_t tx_state;
 
logic icmp_tx_start;
 
logic tcp_pending;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx || !link_ready) begin
        tcp_pending <= 0;
    end else begin
        if (tx_state == TX_IDLE && tcp_pending) tcp_pending <= 0;
        else if (sess_ctrl_start || iltx_start) tcp_pending <= 1;
    end
end
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        tx_state <= TX_IDLE;
        ethtx_start <= 0;
        arp_start <= 0;
        icmp_tx_start <= 0;
        tx_is_arp <= 0;
        tx_is_tcp <= 0;
    end else begin
        ethtx_start <= 0;
        arp_start <= 0;
        icmp_tx_start <= 0;
        unique case (tx_state)
        TX_IDLE: begin
            if (link_ready && arp_pending) begin
                arp_start <= 1;
                ethtx_start <= 1;
                tx_is_arp <= 1;
                tx_is_tcp <= 0;
                tx_state <= TX_WAIT;
            end else if (link_ready && tcp_pending) begin
                ethtx_start <= 1;
                tx_is_arp <= 0;
                tx_is_tcp <= 1;
                tx_state <= TX_WAIT;
            end else if (link_ready && icmp_fifo_valid_tx) begin
                icmp_tx_start <= 1;
                ethtx_start <= 1;
                tx_is_arp <= 0;
                tx_is_tcp <= 0;
                tx_state <= TX_WAIT;
            end
        end
            TX_WAIT: begin
                if (ethtx_done) tx_state <= TX_IDLE;
            end
        endcase
    end
end
 
//assign uart_tx = 1'b1; //temp until i wire uart module
 
logic [7:0] baud_cnt;
logic baud_tick;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        baud_cnt <= 0;
        baud_tick <= 0;
    end else begin
        baud_tick <= 0;
        if (baud_cnt >= 8'd216) begin //baud 115200
            baud_tick <= 1;
            baud_cnt <= 0;
        end else begin
            baud_cnt <= baud_cnt + 1;
        end
    end
end
 
logic [24:0] hb_cnt; //1s uart heartbeat, fill has priority
logic hb_tick;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        hb_cnt <= 0;
        hb_tick <= 0;
    end else begin
        hb_tick <= 0;
        if (hb_cnt >= 25'd24999999) begin
            hb_tick <= 1;
            hb_cnt <= 0;
        end else begin
            hb_cnt <= hb_cnt + 1;
        end
    end
end
 
function automatic logic [7:0] hex_char(input logic [3:0] nibble);
    return (nibble < 4'd10) ? (8'h30 + {4'h0, nibble}) : (8'h41 + {4'h0, nibble} - 8'd10);
endfunction
 
typedef enum logic [1:0] { //uart state machine
    UART_IDLE,
    UART_FILL,
    UART_STATUS
} uart_state_t;
uart_state_t uart_state;
 
logic [7:0] uart_data;
logic uart_ready;
logic [3:0] uart_seq;
logic [31:0] uart_price_latch;
logic uart_side_latch;
logic uart_busy; 
 
logic uart_tx_done;
logic uart_tx_done_r;
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) uart_tx_done_r <= 0;
    else uart_tx_done_r <= uart_tx_done; //defensive
end
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        uart_data <= 0;
        uart_ready <= 0;
        uart_seq <= 0;
        uart_state <= UART_IDLE;
        uart_price_latch <= 0;
        uart_side_latch <= 0;
    end else begin
        uart_ready <= 0;
        case (uart_state)
            UART_IDLE: begin
                if (mm_fill_valid) begin
                    uart_price_latch <= mm_fill_price[63:32]; //upper 32 bits
                    uart_side_latch <= mm_fill_side;
                    uart_seq <= 0;
                    uart_state <= UART_FILL;
                end else if (hb_tick) begin
                    uart_seq <= 0;
                    uart_state <= UART_STATUS;
                end
            end
 
            UART_FILL: begin
                if ((uart_seq == 0 && !uart_busy) || (uart_seq > 0 && uart_tx_done_r)) begin
                    case (uart_seq)
                        4'd0: uart_data <= uart_side_latch ? 8'h53 : 8'h42;
                        4'd1: uart_data <= hex_char(uart_price_latch[31:28]);
                        4'd2: uart_data <= hex_char(uart_price_latch[27:24]);
                        4'd3: uart_data <= hex_char(uart_price_latch[23:20]);
                        4'd4: uart_data <= hex_char(uart_price_latch[19:16]);
                        4'd5: uart_data <= hex_char(uart_price_latch[15:12]);
                        4'd6: uart_data <= hex_char(uart_price_latch[11:8]);
                        4'd7: uart_data <= hex_char(uart_price_latch[7:4]);
                        4'd8: uart_data <= hex_char(uart_price_latch[3:0]);
                        4'd9: uart_data <= 8'h0D;
                        4'd10: uart_data <= 8'h0A;
                        default: uart_data <= 8'h0A;
                    endcase
                    uart_ready <= 1;
                    if (uart_seq >= 4'd10) begin
                        uart_seq <= 0;
                        uart_state <= UART_IDLE;
                    end else begin
                        uart_seq <= uart_seq + 1;
                    end
                end
            end
            
            UART_STATUS: begin
                if ((uart_seq == 0 && !uart_busy) || (uart_seq > 0 && uart_tx_done_r)) begin
                    case (uart_seq)
                        4'd0: uart_data <= 8'h53;
                        4'd1: begin
                            case ({ob_gap_detected, session_error_tx, ob_book_valid, sess_established})
                                4'h0: uart_data <= 8'h30;
                                4'h1: uart_data <= 8'h31;
                                4'h2: uart_data <= 8'h32;
                                4'h3: uart_data <= 8'h33;
                                4'h4: uart_data <= 8'h34;
                                4'h5: uart_data <= 8'h35;
                                4'h6: uart_data <= 8'h36;
                                4'h7: uart_data <= 8'h37;
                                4'h8: uart_data <= 8'h38;
                                4'h9: uart_data <= 8'h39;
                                4'hA: uart_data <= 8'h41;
                                4'hB: uart_data <= 8'h42;
                                4'hC: uart_data <= 8'h43;
                                4'hD: uart_data <= 8'h44;
                                4'hE: uart_data <= 8'h45;
                                4'hF: uart_data <= 8'h46;
                            endcase
                        end
                        4'd2: uart_data <= 8'h0D;
                        4'd3: uart_data <= 8'h0A;
                        default: uart_data <= 8'h0A;
                    endcase
                    uart_ready <= 1;
                    if (uart_seq >= 4'd3) begin
                        uart_seq <= 0;
                        uart_state <= UART_IDLE;
                    end else begin
                        uart_seq <= uart_seq + 1;
                    end
                end
            end
        endcase
    end
end
 
//always_ff @(posedge tx_clk) begin
//    if (rst_sync_tx) begin
//        uart_data <= 0;
//        uart_ready <= 0;
//        uart_seq <= 0;
//        uart_state <= UART_IDLE;
//        uart_price_latch <= 0;
//        uart_side_latch <= 0;
//    end else begin
//        uart_ready <= 0;
//        case (uart_state)
//            UART_IDLE: begin
//                if (hb_tick) begin
//                    uart_seq <= 0;
//                    uart_state <= UART_STATUS;
//                end
//            end
//            UART_STATUS: begin
//                if (!uart_busy && !uart_busy_r) begin
//                    uart_ready <= 1;
//                    case (uart_seq)
//                        4'd0: uart_data <= 8'h41; //'A'
//                        4'd1: uart_data <= 8'h42; //'B'
//                        4'd2: uart_data <= 8'h43; //'C'
//                        default: uart_data <= 8'h0A;
//                    endcase
//                    if (uart_seq >= 4'd2) begin
//                        uart_seq <= 0;
//                        uart_state <= UART_IDLE;
//                    end else begin
//                        uart_seq <= uart_seq + 1;
//                    end
//                end
//            end
//            default: uart_state <= UART_IDLE;
//        endcase
//    end
//end
 
//assign led[0] = uart_busy;
 
logic [15:0] tcp_length_lat;
logic [7:0] tcp_flags_lat;
logic [31:0] tcp_ack_num_lat;
logic [15:0] tcp_payload_csum_lat;
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        tcp_length_lat <= 0;
        tcp_flags_lat <= 0;
        tcp_ack_num_lat <= 0;
        tcp_payload_csum_lat <= 0;
    end else if (sess_ctrl_start || iltx_start) begin
        tcp_length_lat <= tcp_length_mux;
        tcp_flags_lat <= tcp_flags_mux;
        tcp_ack_num_lat <= tcp_ack_num_mux;
        tcp_payload_csum_lat <= tcp_payload_csum_mux;
    end
end
 
logic link_ready_rx_meta, link_ready_rx;
always_ff @(posedge rx_clk) begin
    if (rst_sync_rx) begin
        link_ready_rx_meta <= 0;
        link_ready_rx <= 0;
    end else begin
        link_ready_rx_meta <= link_ready;
        link_ready_rx <= link_ready_rx_meta;
    end
end
 
uarttx u_uarttx (
    .clk(tx_clk),
    .rst(rst_sync_tx),
    .baud(baud_tick),
    .data(uart_data),
    .ready(uart_ready),
    .busy(uart_busy),
    .tx_done(uart_tx_done),
    .tx(uart_tx)
);
 
logic mdio_done;
mdio_init u_mdio_init (
    .clk(clk_100),
    .rst(rst),
    .mdc(eth_mdc),
    .mdio(eth_mdio),
    .done(mdio_done)
);
 
//assign eth_mdc = 0;
//assign eth_mdio = 1;
//assign mdio_done = 1;
 
mii_rx u_mii_rx (
    .rxclk(rx_clk),
    .rxd(rxd),
    .rx_dv(rx_dv),
    .rx_er(1'b0),
    .rst(rst_sync_rx || !link_ready_rx),
    .data(mii_rx_data),
    .valid(mii_rx_valid),
    .frame_active(mii_rx_frame_active)
);
 
eth_parser u_eth_parser (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .data(mii_rx_data),
    .valid(mii_rx_valid),
    .frame_active(mii_rx_frame_active),
    .dest_mac(eth_dest_mac),
    .src_mac(eth_src_mac),
    .ether_type(eth_ether_type),
    .header_valid(eth_header_valid),
    .payload_data(eth_payload_data),
    .payload_valid(eth_payload_valid),
    .frame_done(eth_frame_done),
    .error(eth_error)
);
 
ip_parser u_ip_parser (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .payload(eth_payload_data),
    .payload_valid(eth_payload_valid),
    .header_valid(eth_header_valid),
    .ether(eth_ether_type),
    .frame_done(eth_frame_done),
    .error(eth_error),
    .ip_version(ip_version),
    .ip_ihl(ip_ihl),
    .ip_dscp(ip_dscp),
    .ip_total_len(ip_total_len),
    .ip_id(ip_id),
    .ip_flags(ip_flags),
    .ip_frag_offset(ip_frag_offset),
    .ip_ttl(ip_ttl),
    .ip_protocol(ip_protocol),
    .ip_checksum(ip_checksum),
    .ip_src(ip_src),
    .ip_dest(ip_dest),
    .ip_header_valid(ip_header_valid),
    .ip_checksum_val(ip_checksum_val),
    .ip_is_fragment(ip_is_fragment),
    .ip_payload_data(ip_payload_data),
    .ip_payload_valid(ip_payload_valid),
    .ip_payload_done(ip_payload_done),
    .ip_error(ip_error)
);
 
udp_parser u_udp_parser (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .payload_data(ip_payload_data),
    .payload_valid(ip_payload_valid && (ip_protocol == 8'h11)),
    .ip_header_valid(ip_header_valid),
    .ip_payload_done(ip_payload_done),
    .error(ip_error),
    .ip_protocol(ip_protocol),
    .ip_src(ip_src),
    .ip_dest(ip_dest),
    .udp_src(udp_src),
    .udp_dest(udp_dest),
    .udp_length(udp_length),
    .udp_checksum(udp_checksum),
    .udp_header_valid(udp_header_valid),
    .udp_checksum_val(udp_checksum_val),
    .udp_payload(udp_payload),
    .udp_payload_valid(udp_payload_valid),
    .udp_payload_done(udp_payload_done),
    .udp_error(udp_error)
);
 
mdp_parser #(
    .port(MDP_PORT),
    .sec_id(SEC_ID)
) u_mdp_parser (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .udp_payload(udp_payload),
    .udp_payload_valid(udp_payload_valid),
    .udp_payload_done(udp_payload_done),
    .udp_header_valid(udp_header_valid),
    .udp_dest(udp_dest),
    .udp_error(udp_error),
    .mdp_seq_num(mdp_seq_num),
    .mdp_sending_time(mdp_sending_time),
    .mdp_pkt_valid(mdp_pkt_valid),
    .entry_price(mdp_entry_price),
    .entry_size(mdp_entry_size),
    .entry_price_level(mdp_entry_price_level),
    .entry_update_action(mdp_entry_update_action),
    .entry_type(mdp_entry_type),
    .is_snapshot(mdp_is_snapshot),
    .entry_valid(mdp_entry_valid),
    .mdp_done(mdp_done),
    .mdp_error(mdp_error),
    .trade_price(mdp_trade_price),
    .trade_size(mdp_trade_size),
    .trade_aggressor(mdp_trade_aggressor),
    .trade_valid(mdp_trade_valid)
);
 
order_book u_order_book (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .entry_price(mdp_entry_price),
    .entry_size(mdp_entry_size),
    .entry_price_level(mdp_entry_price_level),
    .entry_update_action(mdp_entry_update_action),
    .entry_type(mdp_entry_type),
    .is_snapshot(mdp_is_snapshot),
    .entry_valid(mdp_entry_valid),
    .mdp_done(mdp_done),
    .mdp_seq_num(mdp_seq_num),
    .mdp_pkt_valid(mdp_pkt_valid),
    .best_bid_price(ob_best_bid_price),
    .best_bid_size(ob_best_bid_size),
    .best_ask_price(ob_best_ask_price),
    .best_ask_size(ob_best_ask_size),
    .rd_level(ob_rd_level),
    .rd_side(ob_rd_side),
    .rd_price(ob_rd_price),
    .rd_size(ob_rd_size),
    .book_valid(ob_book_valid),
    .gap_detected(ob_gap_detected)
);
 
icmp_parser u_icmp_parser (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .payload(ip_payload_data),
    .payload_valid(ip_payload_valid),
    .ip_header_valid(ip_header_valid),
    .ip_payload_done(ip_payload_done),
    .ip_protocol(ip_protocol),
    .error(ip_error),
    .icmp_type(icmp_type),
    .icmp_code(icmp_code),
    .icmp_checksum(icmp_checksum_rx),
    .icmp_identifier(icmp_identifier),
    .icmp_seq_num(icmp_seq_num),
    .icmp_header_valid(icmp_header_valid),
    .icmp_checksum_val(icmp_checksum_val),
    .icmp_payload_data(icmp_payload_data),
    .icmp_payload_valid(icmp_payload_valid),
    .icmp_payload_done(icmp_payload_done),
    .icmp_error(icmp_error)
);
 
tcp_rx u_tcp_rx (
    .rx_clk(rx_clk),
    .rst(rst_sync_rx),
    .src_ip(ip_src),
    .dst_ip(ip_dest),
    .tcp_length(tcp_segment_length),
    .data_in(ip_payload_data),
    .data_in_valid(tcp_ip_payload_valid),
    .data_in_last(tcp_ip_payload_done_rx),
    .data_in_ready(tcprx_data_in_ready),
    .src_port(tcprx_src_port),
    .dst_port(tcprx_dst_port),
    .seq_num(tcprx_seq_num),
    .ack_num(tcprx_ack_num),
    .flags(tcprx_flags),
    .window_size(tcprx_window_size),
    .header_valid(tcprx_header_valid),
    .payload_data(tcprx_payload_data),
    .payload_valid(tcprx_payload_valid),
    .payload_ready(tcprx_payload_ready),
    .rx_syn(tcprx_rx_syn),
    .rx_ack(tcprx_rx_ack),
    .rx_fin(tcprx_rx_fin),
    .rx_rst(tcprx_rx_rst),
    .csum_error(tcprx_csum_error)
);
 
ilink_rx u_ilink_rx (
    .clk(rx_clk),
    .rst(rst_sync_rx),
    .payload_data(tcprx_payload_data),
    .payload_valid(tcprx_payload_valid),
    .payload_ready(ilrx_payload_ready),
    .neg_response(ilrx_neg_response),
    .estab_ack(ilrx_estab_ack),
    .session_error(ilrx_session_error),
    .reject_reason(ilrx_reject_reason),
    .next_seq_no(ilrx_next_seq_no),
    .rx_next_seq_no(ilrx_rx_next_seq_no),
    .send_sequence(ilrx_send_sequence),
    .bid_order_id(ilrx_bid_order_id),
    .ask_order_id(ilrx_ask_order_id),
    .exec_new(ilrx_exec_new),
    .exec_reject(ilrx_exec_reject),
    .exec_elimination(ilrx_exec_elimination),
    .exec_trade(ilrx_exec_trade),
    .exec_modify(ilrx_exec_modify),
    .exec_cancel(ilrx_exec_cancel),
    .unsolicited_cancel(ilrx_unsolicited_cancel),
    .ocr_reject(ilrx_ocr_reject),
    .business_reject(ilrx_business_reject),
    .gap_detected(ilrx_gap_detected),
    .gap_from_seq(ilrx_gap_from_seq),
    .gap_count(ilrx_gap_count),
    .fill_price(ilrx_fill_price),
    .fill_qty(ilrx_fill_qty),
    .fill_leaves_qty(ilrx_fill_leaves_qty),
    .fill_cum_qty(ilrx_fill_cum_qty),
    .fill_side(ilrx_fill_side),
    .fill_clord_id(ilrx_fill_clord_id),
    .exec_id(ilrx_exec_id),
    .ord_rej_reason(ilrx_ord_rej_reason),
    .cxl_rej_reason(ilrx_cxl_rej_reason),
    .order_id_out(ilrx_order_id_out),
    .biz_rej_reason(ilrx_biz_rej_reason),
    .biz_text(ilrx_biz_text)
);
 
assign tcprx_payload_ready = ilrx_payload_ready;
 
mm_core #(
    .HALF_SPREAD(HALF_SPREAD),
    .MAX_POSITION(MAX_POSITION),
    .QUOTE_SIZE(QUOTE_SIZE),
    .MAX_ORDER_RATE(MAX_ORDER_RATE),
    .LOSS_LIMIT(LOSS_LIMIT),
    .VWAP_LEVELS(VWAP_LEVELS),
    .SKEW_PER_CONTRACT(SKEW_PER_CONTRACT),
    .REFRESH_TICKS(REFRESH_TICKS),
    .CLK_FREQ(CLK_FREQ),
    .OFI_DECAY_TICKS(OFI_DECAY_TICKS),
    .OFI_SCALE(OFI_SCALE),
    .OFI_THRESHOLD(OFI_THRESHOLD)
) u_mm_core (
    .clk(tx_clk),
    .rst(rst_sync_tx),
    .best_bid_price(mm_best_bid_price_r),
    .best_bid_size(mm_best_bid_size_r),
    .best_ask_price(mm_best_ask_price_r),
    .best_ask_size(mm_best_ask_size_r),
    .book_valid(mm_book_valid_r),
    .gap_detected(ob_gap_detected),
    .rd_level(mm_rd_level),
    .rd_side(mm_rd_side),
    .rd_price(ob_rd_price),
    .rd_size(ob_rd_size),
    .fill_valid(mm_fill_valid),
    .fill_price(mm_fill_price),
    .fill_size(mm_fill_size),
    .fill_side(mm_fill_side),
    .trade_price(mm_trade_price_r),
    .trade_size(mm_trade_size_r),
    .trade_aggressor(mm_trade_aggressor_r),
    .trade_valid(mm_trade_valid_r),
    .bid_price(mm_bid_price),
    .bid_size(mm_bid_size),
    .ask_price(mm_ask_price),
    .ask_size(mm_ask_size),
    .quote_valid(mm_quote_valid),
    .cancel_bid(mm_cancel_bid),
    .cancel_ask(mm_cancel_ask),
    .risk_breach(mm_risk_breach),
    .directional_valid(mm_directional_valid),
    .directional_side(mm_directional_side),
    .directional_price(mm_directional_price),
    .directional_size(mm_directional_size)
);
 
//logic tcp_connect_sent; //send once
//logic tcp_connect_pulse;
//always_ff @(posedge tx_clk) begin
//    if (rst_sync_tx) begin
//        tcp_connect_sent <= 0;
//        tcp_connect_pulse <= 0;
//    end else begin
//        tcp_connect_pulse <= 0;
//        if (!tcp_connect_sent && !sess_established) begin
//            tcp_connect_pulse <= 1;
//            tcp_connect_sent <= 1;
//        end
//    end
//end
 
logic tcp_connect_sent;
logic tcp_connect_pulse;
logic [26:0] link_delay;
//logic link_ready;
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        link_delay <= 0;
        link_ready <= 0;
    end else if (!link_ready) begin
        link_delay <= link_delay + 1;
        if (link_delay == 27'd74999999) link_ready <= 1;
    end
end
 
//always_ff @(posedge tx_clk) begin
//    if (rst_sync_tx) begin
//        tcp_connect_sent <= 0;
////        tcp_connect_sent <= 1; //test
//        tcp_connect_pulse <= 0;
//    end else begin
//        tcp_connect_pulse <= 0;
//        if (link_ready && !tcp_connect_sent && !sess_established) begin
//            tcp_connect_pulse <= 1;
//            tcp_connect_sent <= 1;
//        end
//    end
//end
 
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) begin
        tcp_connect_sent <= 0;
        tcp_connect_pulse <= 0;
    end else begin
        tcp_connect_pulse <= 0;
        if (link_ready && !tcp_connect_sent && !sess_established && gateway_mac != 0) begin
            tcp_connect_pulse <= 1;
            tcp_connect_sent <= 1;
        end
    end
end
 
tcp_session #(
    .RETRANSMIT_CYCLES(RETRANSMIT_CYCLES),
    .KEEPALIVE_CYCLES(KEEPALIVE_CYCLES)
) u_tcp_session (
    .clk(tx_clk),
    .rst(rst_sync_tx),
    .connect(tcp_connect_pulse),
    .disconnect(1'b0),
    .src_port(SRC_PORT),
    .dst_port(CME_PORT),
    .window_size(16'hFFFF),
    .isn(ISN),
    .rx_syn(tcprx_syn_tx),
    .rx_ack(tcprx_ack_tx),
    .rx_fin(tcprx_fin_tx),
    .rx_rst(tcprx_rst_tx),
    .rx_seq_num(tcprx_seq_tx),
    .header_valid(tcprx_hv_tx),
    .ctrl_start(sess_ctrl_start),
    .ctrl_flags(sess_ctrl_flags),
    .ctrl_ack_num(sess_ctrl_ack_num),
    .ctrl_tcp_length(sess_ctrl_tcp_length),
    .ctrl_payload_csum(sess_ctrl_payload_csum),
    .tx_done(tcptx_done),
    .load_seq(sess_load_seq),
    .init_seq(sess_init_seq),
    .tx_grant(sess_tx_grant),
    .established(sess_established),
    .closed(sess_closed)
);
 
ilink_tx u_ilink_tx (
    .clk(tx_clk),
    .rst(rst_sync_tx),
    .established(sess_established),
    .hmac_negotiate(HMAC_NEGOTIATE),
    .hmac_establish(HMAC_ESTABLISH),
    .req_timestamp(64'h0),
    .neg_response(neg_response_tx),
    .estab_ack(estab_ack_tx),
    .ilink_established(iltx_ilink_established),
    .tx_grant(sess_tx_grant),
    .start(iltx_start),
    .flags(iltx_flags),
    .tcp_length(iltx_tcp_length),
    .payload_csum(iltx_payload_csum),
    .tx_done(tcptx_done),
    .payload_in_data(iltx_payload_data),
    .payload_in_valid(iltx_payload_valid),
    .payload_in_last(iltx_payload_last),
    .payload_in_ready(iltx_payload_ready),
    .quote_valid(mm_quote_valid),
    .bid_price(mm_bid_price),
    .bid_size(mm_bid_size),
    .ask_price(mm_ask_price),
    .ask_size(mm_ask_size),
    .cancel_bid(mm_cancel_bid),
    .cancel_ask(mm_cancel_ask),
    .directional_valid(mm_directional_valid),
    .directional_side(mm_directional_side),
    .directional_price(mm_directional_price),
    .directional_size(mm_directional_size),
    .bid_order_id(bid_order_id_tx),
    .ask_order_id(ask_order_id_tx)
);
 
icmp_csum_adjust u_csum_adjust (
    .csum_in(rep_icmp_checksum_rx),
    .csum_out(icmp_checksum_tx)
);
 
icmp_tx u_icmp_tx (
    .tx_clk(tx_clk),
    .rst(rst_sync_tx),
    .identifier(rep_identifier),
    .seq(rep_seq),
    .icmp_checksum(icmp_checksum_tx),
    .start(icmp_tx_start),
    .done(icmp_tx_done),
    .payload_in_data(icmp_fifo_mem[icmp_fifo_rd_ptr]),
    .payload_in_valid(icmp_fifo_valid_tx),
    .payload_in_ready(icmp_fifo_ready),
    .payload_data(ictx_data),
    .payload_valid(ictx_valid),
    .payload_ready(ictx_ready)
);
 
tcp_tx u_tcp_tx (
    .tx_clk(tx_clk),
    .rst(rst_sync_tx),
    .src_ip(MY_IP),
    .dst_ip(CME_IP),
    .tcp_length(tcp_length_lat),
    .src_port(SRC_PORT),
    .dst_port(CME_PORT),
    .ack_num(tcp_ack_num_lat),
    .flags(tcp_flags_lat),
    .window_size(16'hFFFF),
    .payload_csum(tcp_payload_csum_lat),
    .init_seq(sess_init_seq),
    .load_seq(sess_load_seq),
    .start(tcp_start_mux),
    .done(tcptx_done),
    .payload_in_data(tcp_pld_data_mux),
    .payload_in_valid(tcp_pld_valid_mux),
    .payload_in_last(tcp_pld_last_mux),
    .payload_in_ready(tcptx_payload_ready),
    .payload_data(tcptx_payload_data),
    .payload_valid(tcptx_payload_valid),
    .payload_ready(ip_payload_mux_ready)
);
 
logic [15:0] ip_total_len_lat;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) ip_total_len_lat <= 0;
    else if (sess_ctrl_start || iltx_start) ip_total_len_lat <= tcp_length_mux + 16'd20;
end
 
ip_tx u_ip_tx (
    .tx_clk(tx_clk),
    .rst(rst_sync_tx),
    .src_ip(MY_IP),
    .dst_ip(ip_dst_mux),
    .protocol(ip_protocol_mux),
    .total_length(ip_total_len_lat),
    .identification(ip_id_mux),
    .start(iptx_start),
    .done(iptx_done),
    .payload_data(ip_payload_mux_data),
    .payload_valid(ip_payload_mux_valid),
    .payload_ready(ip_payload_mux_ready),
    .tx_data(iptx_data),
    .tx_valid(iptx_valid),
    .tx_ready(iptx_ready)
);
 
eth_tx u_eth_tx (
    .tx_clk(tx_clk),
    .rst(rst_sync_tx || !link_ready),
    .dst_mac(mux_dst_mac),
    .ether_type(mux_ether_type),
    .payload_data(mux_payload_data),
    .payload_valid(mux_payload_valid),
    .start(ethtx_start),
    .payload_ready(mux_payload_ready),
    .done(ethtx_done),
    .txd(ethtx_data),
    .tx_valid(ethtx_valid),
    .tx_ready(ethtx_ready)
);
 
mii_tx u_mii_tx (
    .tx_clk(tx_clk),
    .rst(rst_sync_tx || !link_ready),
    .data(ethtx_data),
    .valid(ethtx_valid),
    .ready(ethtx_ready),
    .txd(txd),
    .tx_en(tx_en)
);
 
arp_handler #(
    .MY_IP(MY_IP),
    .MY_MAC(MY_MAC)
) u_arp_handler (
    .rx_clk(rx_clk),
    .tx_clk(tx_clk),
    .rst(rst),
    .eth_ether_type(eth_ether_type),
    .eth_header_valid(eth_header_valid),
    .eth_payload_data(eth_payload_data),
    .eth_payload_valid(eth_payload_valid),
    .eth_frame_done(eth_frame_done),
    .eth_error(eth_error),
    .reply_dst_mac(arp_reply_dst_mac),
    .pending(arp_pending),
    .start(arp_start),
    .done(arp_done),
    .payload_data(arp_payload_data),
    .payload_valid(arp_payload_valid),
    .payload_ready(arp_payload_ready)
);
 
//DEBUG LEDS
//assign led[0] = session_error_tx; //ilink session error
//assign led[1] = ob_gap_detected; //order book gap
//assign led[2] = ilrx_exec_trade; //fill received
//assign led[3] = ob_book_valid; //book live
 
//assign led[0] = arp_pending;
//assign led[1] = tcp_pending;
//assign led[2] = icmp_fifo_valid_tx;
//assign led[3] = tx_is_arp;
 
//assign led[0] = ethtx_start;
//assign led[1] = ethtx_valid;
//assign led[2] = tx_is_tcp;
//assign led[3] = tx_is_arp;
 
//assign led[0] = mdio_done;
//assign led[1] = sess_ctrl_start;
//assign led[2] = tcp_connect_pulse;
//assign led[3] = link_ready;
 
//assign led[0] = link_ready;
//assign led[1] = arp_pending;
//assign led[2] = icmp_fifo_valid_tx;
//assign led[3] = tx_en;
 
//assign led[0] = link_ready;
//assign led[1] = tx_en;
//assign led[2] = sess_ctrl_start;
//assign led[3] = tcp_connect_pulse;
 
logic tcp_pulse_seen;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) tcp_pulse_seen <= 0;
    else if (tcp_connect_pulse) tcp_pulse_seen <= 1;
end
 
logic sess_start_seen;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) sess_start_seen <= 0;
    else if (sess_ctrl_start) sess_start_seen <= 1;
end
 
logic ethtx_done_seen;
always_ff @(posedge tx_clk) begin
    if (rst_sync_tx) ethtx_done_seen <= 0;
    else if (ethtx_done) ethtx_done_seen <= 1;
end
 
assign led[0] = link_ready;
assign led[1] = tx_en;
assign led[2] = sess_start_seen;
assign led[3] = ethtx_done_seen;
 
endmodule