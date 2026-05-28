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
assign tcp_segment_length = ip_total_len - {10'b0, ip_ihl, 2'b00}; //ip_total_len - ip_ihl*4
 
logic tcp_ip_payload_valid;
assign tcp_ip_payload_valid = ip_payload_valid && (ip_protocol == 8'h06);
 
logic tcp_ip_payload_done_rx;
assign tcp_ip_payload_done_rx = ip_payload_done && (ip_protocol == 8'h06);

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



//mm core - tx clk :(
localparam MD2_FIFO_DEPTH = 16;
localparam MD2_FIFO_AW = $clog2(MD2_FIFO_DEPTH);
localparam MD2_WIDTH = 292;
 
logic [MD2_WIDTH-1:0] md2_fifo_mem [0:MD2_FIFO_DEPTH-1];
logic [MD2_FIFO_AW-1:0] md2_wr_ptr;
logic [MD2_FIFO_AW-1:0] md2_rd_ptr;
 
logic [MD2_FIFO_AW-1:0] md2_wr_ptr_meta, md2_wr_ptr_tx;
always_ff @(posedge tx_clk) begin //metastability
    if (rst) begin
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
    if (rst) begin
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
    if (rst) begin
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
    if (rst) begin
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
    if (rst) begin
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
    if (rst) begin
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
    if (rst) begin
        neg_response_meta <= 0;
        neg_response_tx <= 0;
    end else begin
        neg_response_meta <= ilrx_neg_response;
        neg_response_tx <= neg_response_meta;
    end
end
 
logic estab_ack_meta, estab_ack_tx; //estab_ack pulse sync
always_ff @(posedge tx_clk) begin
    if (rst) begin
        estab_ack_meta <= 0;
        estab_ack_tx <= 0;
    end else begin
        estab_ack_meta <= ilrx_estab_ack;
        estab_ack_tx <= estab_ack_meta;
    end
end

logic send_sequence_meta, send_sequence_tx;
always_ff @(posedge tx_clk) begin
    if (rst) begin
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
    if (rst) begin
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
    if (rst) begin
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
 
logic tcprx_syn_meta, tcprx_syn_tx; //synchronizer ffs
logic tcprx_ack_meta, tcprx_ack_tx;
logic tcprx_fin_meta, tcprx_fin_tx;
logic tcprx_rst_meta, tcprx_rst_tx;
logic tcprx_hv_meta, tcprx_hv_tx;
logic [31:0] tcprx_seq_meta, tcprx_seq_tx;
 
always_ff @(posedge tx_clk) begin
    if (rst) begin
        tcprx_syn_meta <= 0; 
        tcprx_syn_tx <= 0;
        tcprx_ack_meta <= 0; 
        tcprx_ack_tx <= 0;
        tcprx_fin_meta <= 0; 
        tcprx_fin_tx <= 0;
        tcprx_rst_meta <= 0; 
        tcprx_rst_tx <= 0;
        tcprx_hv_meta <= 0; 
        tcprx_hv_tx <= 0;
        tcprx_seq_meta <= 0; 
        tcprx_seq_tx <= 0;
    end else begin
        tcprx_syn_meta <= tcprx_rx_syn; 
        tcprx_syn_tx <= tcprx_syn_meta;
        
        tcprx_ack_meta <= tcprx_rx_ack; 
        tcprx_ack_tx <= tcprx_ack_meta;
        
        tcprx_fin_meta <= tcprx_rx_fin; 
        tcprx_fin_tx <= tcprx_fin_meta;
        
        tcprx_rst_meta <= tcprx_rx_rst; 
        tcprx_rst_tx <= tcprx_rst_meta;
        
        tcprx_hv_meta <= tcprx_header_valid; 
        tcprx_hv_tx <= tcprx_hv_meta;
        
        tcprx_seq_meta <= tcprx_seq_num; 
        tcprx_seq_tx <= tcprx_seq_meta;
    end
end

logic [7:0] tcptx_payload_data; //tcp tx to ip tx
logic tcptx_payload_valid;
logic tcptx_payload_ready;
logic tcptx_done;

endmodule
