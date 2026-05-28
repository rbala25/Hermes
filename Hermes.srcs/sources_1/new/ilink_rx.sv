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
 
    //additional decoded fields
    output logic [15:0] ord_rej_reason,
    output logic [15:0] cxl_rej_reason,
    output logic [63:0] order_id_out,
    output logic [15:0] biz_rej_reason,
    output logic [2047:0] biz_text
);
 
logic dispatch_pending;
logic [15:0] dispatch_tid;
 
//gap detection latch — set on last body byte, fired on dispatch cycle
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


endmodule
