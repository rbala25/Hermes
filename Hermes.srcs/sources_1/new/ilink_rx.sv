`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/27/2026 08:53:39 PM
// Design Name: 
// Module Name: ilink_rx
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


module ilink_rx(
    input logic clk,
    input logic rst,
 
    input logic [7:0] payload_data, //tcp rx
    input logic payload_valid,
    output logic payload_ready,
 
    output logic neg_response,
    output logic estab_ack,
    output logic session_error,
    output logic [383:0] reject_reason, 
    output logic [31:0] next_seq_no,
    output logic [31:0] rx_next_seq_no,
    output logic send_sequence,
 
    output logic [63:0] bid_order_id, //goes into ilink_tx
    output logic [63:0] ask_order_id,
 
    output logic exec_new, //mm core
    output logic exec_reject,
    output logic exec_elimination,
    output logic exec_trade,
    output logic exec_modify,
    output logic exec_cancel,
    output logic unsolicited_cancel,
    output logic ocr_reject,
    output logic business_reject,
 
    output logic gap_detected,
    output logic [31:0] gap_from_seq,
    output logic [31:0] gap_count,
 
    output logic signed [63:0] fill_price, //back into mm core
    output logic [31:0] fill_qty,
    output logic [31:0] fill_leaves_qty,
    output logic [31:0] fill_cum_qty,
    output logic [7:0] fill_side,
    output logic [159:0] fill_clord_id,
    output logic [319:0] exec_id,

    output logic [15:0] ord_rej_reason,
    output logic [15:0] cxl_rej_reason,
    output logic [63:0] order_id_out,
    output logic [15:0] biz_rej_reason,
    output logic [2047:0] biz_text
);
 
logic dispatch_pending;
logic [15:0] dispatch_tid;

logic gap_pending;
logic [31:0] gap_from_latch;
logic [31:0] gap_count_latch;
 
typedef enum logic [2:0] {
    s_idle,
    s_sofh,
    s_sbe_hdr,
    s_body,
    s_skip
} state_t;
 
state_t state;

logic [15:0] pos;
logic [15:0] sofh_total_len; 
logic [15:0] template_id;
logic [15:0] block_length;

logic [31:0] expected_seq; //for gap detection
logic expected_seq_valid;
 
logic [31:0] f_seq_num; //intermediate latches
logic [31:0] f_next_seq_no;
logic [31:0] f_rx_next_seq_no;
logic [7:0] f_keepalive_lapsed;
logic [383:0] f_reject_reason;
logic signed [63:0] f_price;
logic signed [63:0] f_last_px;
logic [63:0] f_order_id;
logic [31:0] f_order_qty;
logic [31:0] f_last_qty;
logic [31:0] f_cum_qty;
logic [31:0] f_leaves_qty;
logic [7:0] f_side;
logic [7:0] f_aggressor;
logic [7:0] f_exec_restatement_reason;
logic [15:0] f_ord_rej_reason;
logic [15:0] f_cxl_rej_reason;
logic [319:0] f_exec_id;
logic [159:0] f_clord_id;
logic [63:0] f_ocr_order_id;
logic [159:0] f_ocr_clord_id;
logic [15:0] f_ocr_cxl_rej_reason;
logic [2047:0] f_biz_text;
logic [15:0] f_biz_rej_reason;

logic [15:0] bpos; //body ctr
assign bpos = pos - 16'd12;

logic [15:0] exec_id_off;   //bpos - 12
logic [15:0] clord_off_72;  //bpos - 72
logic [15:0] clord_off_328; //bpos - 328 
logic [15:0] biz_text_off;  //bpos - 12
assign exec_id_off   = bpos - 16'd12;
assign clord_off_72  = bpos - 16'd72;
assign clord_off_328 = bpos - 16'd328;
assign biz_text_off  = bpos - 16'd12;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= s_idle;
        pos <= 0;
        sofh_total_len <= 0;
        template_id <= 0;
        block_length <= 0;
        expected_seq <= 0;
        expected_seq_valid <= 0;
        bid_order_id <= {64{1'b1}};
        dispatch_pending <= 0;
        dispatch_tid <= 0;
        gap_pending <= 0;
        gap_from_latch <= 0;
        gap_count_latch <= 0;
        ask_order_id <= {64{1'b1}};

        neg_response <= 0;
        estab_ack <= 0;
        session_error <= 0;
        send_sequence <= 0;
        exec_new <= 0;
        exec_reject <= 0;
        exec_elimination <= 0;
        exec_trade <= 0;
        exec_modify <= 0;
        exec_cancel <= 0;
        unsolicited_cancel <= 0;
        ocr_reject <= 0;
        business_reject <= 0;
        gap_detected <= 0;

        reject_reason <= 0;
        next_seq_no <= 0;
        rx_next_seq_no <= 0;
        gap_from_seq <= 0;
        gap_count <= 0;
        fill_price <= 0;
        fill_qty <= 0;
        fill_leaves_qty <= 0;
        fill_cum_qty <= 0;
        fill_side <= 0;
        fill_clord_id <= 0;
        exec_id <= 0;
        ord_rej_reason <= 0;
        cxl_rej_reason <= 0;
        order_id_out <= 0;
        biz_rej_reason <= 0;
        biz_text <= 0;
        payload_ready <= 0;
        //clear field temps
        f_seq_num <= 0;
        f_next_seq_no <= 0;
        f_rx_next_seq_no <= 0;
        f_keepalive_lapsed <= 0;
        f_reject_reason <= 0;
        f_price <= 0;
        f_last_px <= 0;
        f_order_id <= 0;
        f_order_qty <= 0;
        f_last_qty <= 0;
        f_cum_qty <= 0;
        f_leaves_qty <= 0;
        f_side <= 0;
        f_aggressor <= 0;
        f_exec_restatement_reason <= 8'hFF;
        f_ord_rej_reason <= 0;
        f_cxl_rej_reason <= 0;
        f_exec_id <= 0;
        f_clord_id <= 0;
        f_ocr_order_id <= 0;
        f_ocr_clord_id <= 0;
        f_ocr_cxl_rej_reason <= 0;
        f_biz_text <= 0;
        f_biz_rej_reason <= 0;
    end else begin
        neg_response <= 0;
        estab_ack <= 0;
        session_error <= 0;
        send_sequence <= 0;
        exec_new <= 0;
        exec_reject <= 0;
        exec_elimination <= 0;
        exec_trade <= 0;
        exec_modify <= 0;
        exec_cancel <= 0;
        unsolicited_cancel <= 0;
        ocr_reject <= 0;
        business_reject <= 0;
        gap_detected <= 0;
        
    end
end
endmodule
