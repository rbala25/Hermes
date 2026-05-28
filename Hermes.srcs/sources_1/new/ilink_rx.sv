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

//501 - negotiation response, 502 - negotiation rej
//504 - establishment ack, 505 - estab rej
//506 - seq (heartbeat)
//507 - terminate
//521 - business reject (app level)
//522 - exec report new
//523 - exec report reject
//524 - exec report elimination
//525 - exec report trade outright (yay)
//531 - exec report modfiy
//534 - exec report cancel
//535 - order cancel reject

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
        
        if (dispatch_pending) begin //one cycle extra bc of NBA's and f_ latches
            dispatch_pending <= 0;
            if (gap_pending) begin
                gap_pending <= 0;
                gap_detected <= 1;
                gap_from_seq <= gap_from_latch;
                gap_count <= gap_count_latch;
            end
            
            case (dispatch_tid)
                16'd501: neg_response <= 1; //no fields
 
                16'd502: begin
                    session_error <= 1;
                    reject_reason <= f_reject_reason;
                end
 
                16'd504: begin
                    estab_ack <= 1;
                    next_seq_no <= f_next_seq_no;
                    expected_seq <= f_next_seq_no;
                    expected_seq_valid <= 1;
                end
 
                16'd505: begin
                    session_error <= 1;
                    reject_reason <= f_reject_reason;
                end
 
                16'd506: begin
                    rx_next_seq_no <= f_rx_next_seq_no;
                    if (f_keepalive_lapsed == 8'd1) send_sequence <= 1; //1 - heartbeat lapsed
                end
 
                16'd507: begin
                    session_error <= 1;
                    reject_reason <= f_reject_reason;
                end
 
                16'd521: begin
                    biz_text <= f_biz_text;
                    biz_rej_reason <= f_biz_rej_reason;
                    business_reject <= 1;
                end
 
                16'd522: begin
                    exec_id <= f_exec_id;
                    fill_clord_id <= f_clord_id;
                    order_id_out <= f_order_id;
                    fill_price <= f_price;
                    fill_side <= f_side;
                    fill_qty <= f_order_qty;
                    if (f_side == 8'd1) bid_order_id <= f_order_id;
                    else if (f_side == 8'd2) ask_order_id <= f_order_id;
                    exec_new <= 1;
                end
 
                16'd523: begin
                    fill_clord_id <= f_clord_id;
                    fill_side <= f_side;
                    ord_rej_reason <= f_ord_rej_reason;
                    exec_reject <= 1;
                end
 
                16'd524: begin
                    fill_clord_id <= f_clord_id;
                    order_id_out <= f_order_id;
                    fill_cum_qty <= f_cum_qty;
                    fill_side <= f_side;
                    exec_elimination <= 1;
                end
 
                16'd525: begin
                    exec_id <= f_exec_id;
                    fill_clord_id <= f_clord_id;
                    fill_price <= f_last_px;
                    order_id_out <= f_order_id;
                    fill_qty <= f_last_qty;
                    fill_cum_qty <= f_cum_qty;
                    fill_leaves_qty <= f_leaves_qty;
                    fill_side <= f_side;
                    exec_trade <= 1;
                end
 
                16'd531: begin
                    fill_clord_id <= f_clord_id;
                    order_id_out <= f_order_id;
                    fill_price <= f_price;
                    fill_cum_qty <= f_cum_qty;
                    fill_leaves_qty <= f_leaves_qty;
                    fill_side <= f_side;
                    exec_modify <= 1;
                end
 
                16'd534: begin
                    fill_clord_id <= f_clord_id;
                    order_id_out <= f_order_id;
                    fill_cum_qty <= f_cum_qty;
                    fill_side <= f_side;
                    exec_cancel <= 1;
                    if (f_exec_restatement_reason != 8'hFF) unsolicited_cancel <= 1;
                end
 
                16'd535: begin
                    fill_clord_id <= f_ocr_clord_id;
                    order_id_out <= f_ocr_order_id;
                    cxl_rej_reason <= f_ocr_cxl_rej_reason;
                    ocr_reject <= 1;
                end
 
                default: ;
            endcase
        end
        
        payload_ready <= 1;
        
        if(payload_valid) begin
            unique case (state)
                s_idle: begin
                    sofh_total_len[7:0] <= payload_data;
                    pos <= 1;
                    state <= s_sofh;
                end
                
                s_sofh: begin
                    case (pos)
                        16'd1: sofh_total_len[15:8] <= payload_data;
                        16'd2: ; //ignore encoding type
                        16'd3: begin
                            block_length <= 0;
                            template_id <= 0;
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
                            state <= s_sbe_hdr;
                        end
                        default: ;
                    endcase
                    pos <= pos + 16'd1;
                end
                
                s_sbe_hdr: begin
                    case (pos)
                        16'd4: block_length[7:0] <= payload_data;
                        16'd5: block_length[15:8] <= payload_data;
                        16'd6: template_id[7:0] <= payload_data;
                        16'd7: template_id[15:8] <= payload_data;
                        16'd11: begin
                            pos <= pos + 16'd1;
                            if (block_length == 0) begin //dispatch now
                                dispatch_pending <= 1;
                                dispatch_tid <= template_id;
                                begin
                                    logic [15:0] rem;
                                    rem = sofh_total_len - 16'd12;
                                    if (rem > 0) begin //skip rest
                                        state <= s_skip;
                                        block_length <= rem;
                                    end else begin
                                        pos <= 0;
                                        state <= s_idle;
                                    end
                                end
                            end else begin
                                state <= s_body;
                            end
                        end
                        default: ;
                    endcase
                    if (pos != 16'd11)
                        pos <= pos + 16'd1;
                end
                
                s_body: begin
                    if ((template_id == 16'd502 || template_id == 16'd505 || template_id == 16'd507) && bpos < 16'd48) begin //reject reason 502, 505, 507
                        f_reject_reason[{bpos[5:0], 3'b0} +: 8] <= payload_data;
                    end
 
                    if (template_id == 16'd504) begin
                        case (bpos)
                            16'd16: f_next_seq_no[7:0] <= payload_data;
                            16'd17: f_next_seq_no[15:8] <= payload_data;
                            16'd18: f_next_seq_no[23:16] <= payload_data;
                            16'd19: f_next_seq_no[31:24] <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd506) begin
                        case (bpos)
                            16'd8:  f_rx_next_seq_no[7:0] <= payload_data;
                            16'd9:  f_rx_next_seq_no[15:8] <= payload_data;
                            16'd10: f_rx_next_seq_no[23:16] <= payload_data;
                            16'd11: f_rx_next_seq_no[31:24] <= payload_data;
                            16'd13: f_keepalive_lapsed <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd521 || template_id == 16'd522 || template_id == 16'd523 || template_id == 16'd524 || 
                        template_id == 16'd525 || template_id == 16'd531 || template_id == 16'd534 || template_id == 16'd535) begin
                        case (bpos) //app messages
                            16'd0: f_seq_num[7:0] <= payload_data;
                            16'd1: f_seq_num[15:8] <= payload_data;
                            16'd2: f_seq_num[23:16] <= payload_data;
                            16'd3: f_seq_num[31:24] <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd522) begin //exec report new
                        if (bpos >= 16'd12 && bpos < 16'd52)
                            f_exec_id[{exec_id_off[5:0], 3'b0} +: 8] <= payload_data;
                        if (bpos >= 16'd72 && bpos < 16'd92)
                            f_clord_id[{clord_off_72[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd100: f_order_id[7:0] <= payload_data;
                            16'd101: f_order_id[15:8] <= payload_data;
                            16'd102: f_order_id[23:16] <= payload_data;
                            16'd103: f_order_id[31:24] <= payload_data;
                            16'd104: f_order_id[39:32] <= payload_data;
                            16'd105: f_order_id[47:40] <= payload_data;
                            16'd106: f_order_id[55:48] <= payload_data;
                            16'd107: f_order_id[63:56] <= payload_data;
                            16'd108: f_price[7:0] <= payload_data;
                            16'd109: f_price[15:8] <= payload_data;
                            16'd110: f_price[23:16] <= payload_data;
                            16'd111: f_price[31:24] <= payload_data;
                            16'd112: f_price[39:32] <= payload_data;
                            16'd113: f_price[47:40] <= payload_data;
                            16'd114: f_price[55:48] <= payload_data;
                            16'd115: f_price[63:56] <= payload_data;
                            16'd173: f_order_qty[7:0] <= payload_data;
                            16'd174: f_order_qty[15:8] <= payload_data;
                            16'd175: f_order_qty[23:16] <= payload_data;
                            16'd176: f_order_qty[31:24] <= payload_data;
                            16'd190: f_side <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd523) begin
                        if (bpos >= 16'd328 && bpos < 16'd348)
                            f_clord_id[{clord_off_328[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd441: f_ord_rej_reason[7:0] <= payload_data;
                            16'd442: f_ord_rej_reason[15:8] <= payload_data;
                            16'd448: f_side <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd524) begin
                        if (bpos >= 16'd72 && bpos < 16'd92)
                            f_clord_id[{clord_off_72[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd100: f_order_id[7:0] <= payload_data;
                            16'd101: f_order_id[15:8] <= payload_data;
                            16'd102: f_order_id[23:16] <= payload_data;
                            16'd103: f_order_id[31:24] <= payload_data;
                            16'd104: f_order_id[39:32] <= payload_data;
                            16'd105: f_order_id[47:40] <= payload_data;
                            16'd106: f_order_id[55:48] <= payload_data;
                            16'd107: f_order_id[63:56] <= payload_data;
                            16'd173: f_cum_qty[7:0] <= payload_data;
                            16'd174: f_cum_qty[15:8] <= payload_data;
                            16'd175: f_cum_qty[23:16] <= payload_data;
                            16'd176: f_cum_qty[31:24] <= payload_data;
                            16'd192: f_side <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd525) begin
                        if (bpos >= 16'd12 && bpos < 16'd52)
                            f_exec_id[{exec_id_off[5:0], 3'b0} +: 8] <= payload_data;
                        if (bpos >= 16'd72 && bpos < 16'd92)
                            f_clord_id[{clord_off_72[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd100: f_last_px[7:0] <= payload_data;
                            16'd101: f_last_px[15:8] <= payload_data;
                            16'd102: f_last_px[23:16] <= payload_data;
                            16'd103: f_last_px[31:24] <= payload_data;
                            16'd104: f_last_px[39:32] <= payload_data;
                            16'd105: f_last_px[47:40] <= payload_data;
                            16'd106: f_last_px[55:48] <= payload_data;
                            16'd107: f_last_px[63:56] <= payload_data;
                            16'd108: f_order_id[7:0] <= payload_data;
                            16'd109: f_order_id[15:8] <= payload_data;
                            16'd110: f_order_id[23:16] <= payload_data;
                            16'd111: f_order_id[31:24] <= payload_data;
                            16'd112: f_order_id[39:32] <= payload_data;
                            16'd113: f_order_id[47:40] <= payload_data;
                            16'd114: f_order_id[55:48] <= payload_data;
                            16'd115: f_order_id[63:56] <= payload_data;
                            16'd193: f_last_qty[7:0] <= payload_data;
                            16'd194: f_last_qty[15:8] <= payload_data;
                            16'd195: f_last_qty[23:16] <= payload_data;
                            16'd196: f_last_qty[31:24] <= payload_data;
                            16'd197: f_cum_qty[7:0] <= payload_data;
                            16'd198: f_cum_qty[15:8] <= payload_data;
                            16'd199: f_cum_qty[23:16] <= payload_data;
                            16'd200: f_cum_qty[31:24] <= payload_data;
                            16'd213: f_leaves_qty[7:0] <= payload_data;
                            16'd214: f_leaves_qty[15:8] <= payload_data;
                            16'd215: f_leaves_qty[23:16] <= payload_data;
                            16'd216: f_leaves_qty[31:24] <= payload_data;
                            16'd223: f_side <= payload_data;
                            16'd227: f_aggressor <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd531) begin
                        if (bpos >= 16'd72 && bpos < 16'd92)
                            f_clord_id[{clord_off_72[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd100: f_order_id[7:0] <= payload_data;
                            16'd101: f_order_id[15:8] <= payload_data;
                            16'd102: f_order_id[23:16] <= payload_data;
                            16'd103: f_order_id[31:24] <= payload_data;
                            16'd104: f_order_id[39:32] <= payload_data;
                            16'd105: f_order_id[47:40] <= payload_data;
                            16'd106: f_order_id[55:48] <= payload_data;
                            16'd107: f_order_id[63:56] <= payload_data;
                            16'd108: f_price[7:0] <= payload_data;
                            16'd109: f_price[15:8] <= payload_data;
                            16'd110: f_price[23:16] <= payload_data;
                            16'd111: f_price[31:24] <= payload_data;
                            16'd112: f_price[39:32] <= payload_data;
                            16'd113: f_price[47:40] <= payload_data;
                            16'd114: f_price[55:48] <= payload_data;
                            16'd115: f_price[63:56] <= payload_data;
                            16'd177: f_cum_qty[7:0] <= payload_data;
                            16'd178: f_cum_qty[15:8] <= payload_data;
                            16'd179: f_cum_qty[23:16] <= payload_data;
                            16'd180: f_cum_qty[31:24] <= payload_data;
                            16'd181: f_leaves_qty[7:0] <= payload_data;
                            16'd182: f_leaves_qty[15:8] <= payload_data;
                            16'd183: f_leaves_qty[23:16] <= payload_data;
                            16'd184: f_leaves_qty[31:24] <= payload_data;
                            16'd198: f_side <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd534) begin
                        if (bpos >= 16'd72 && bpos < 16'd92)
                            f_clord_id[{clord_off_72[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd100: f_order_id[7:0] <= payload_data;
                            16'd101: f_order_id[15:8] <= payload_data;
                            16'd102: f_order_id[23:16] <= payload_data;
                            16'd103: f_order_id[31:24] <= payload_data;
                            16'd104: f_order_id[39:32] <= payload_data;
                            16'd105: f_order_id[47:40] <= payload_data;
                            16'd106: f_order_id[55:48] <= payload_data;
                            16'd107: f_order_id[63:56] <= payload_data;
                            16'd177: f_cum_qty[7:0] <= payload_data;
                            16'd178: f_cum_qty[15:8] <= payload_data;
                            16'd179: f_cum_qty[23:16] <= payload_data;
                            16'd180: f_cum_qty[31:24] <= payload_data;
                            16'd194: f_side <= payload_data;
                            16'd199: f_exec_restatement_reason <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd535) begin //ocr
                        if (bpos >= 16'd328 && bpos < 16'd348)
                            f_ocr_clord_id[{clord_off_328[4:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd356: f_ocr_order_id[7:0] <= payload_data;
                            16'd357: f_ocr_order_id[15:8] <= payload_data;
                            16'd358: f_ocr_order_id[23:16] <= payload_data;
                            16'd359: f_ocr_order_id[31:24] <= payload_data;
                            16'd360: f_ocr_order_id[39:32] <= payload_data;
                            16'd361: f_ocr_order_id[47:40] <= payload_data;
                            16'd362: f_ocr_order_id[55:48] <= payload_data;
                            16'd363: f_ocr_order_id[63:56] <= payload_data;
                            16'd393: f_ocr_cxl_rej_reason[7:0] <= payload_data;
                            16'd394: f_ocr_cxl_rej_reason[15:8] <= payload_data;
                            default: ;
                        endcase
                    end
 
                    if (template_id == 16'd521) begin
                        if (bpos >= 16'd12 && bpos < 16'd268)
                            f_biz_text[{biz_text_off[7:0], 3'b0} +: 8] <= payload_data;
                        case (bpos)
                            16'd323: f_biz_rej_reason[7:0] <= payload_data;
                            16'd324: f_biz_rej_reason[15:8] <= payload_data;
                            default: ;
                        endcase
                    end

                    pos <= pos + 16'd1;
 
                    if (bpos == block_length - 16'd1) begin
                        if (template_id == 16'd521 || template_id == 16'd522 || template_id == 16'd523 || template_id == 16'd524 || 
                            template_id == 16'd525 || template_id == 16'd531 || template_id == 16'd534 || template_id == 16'd535) begin
                            if (expected_seq_valid && f_seq_num != expected_seq) begin
                                gap_pending <= 1;
                                gap_from_latch <= expected_seq;
                                gap_count_latch <= f_seq_num - expected_seq;
                            end
                            expected_seq <= f_seq_num + 32'd1;
                        end
 
                        dispatch_pending <= 1;
                        dispatch_tid <= template_id;
 
                        begin
                            logic [15:0] skip;
                            skip = sofh_total_len - 16'd12 - block_length;
                            if (skip > 0) begin
                                block_length <= skip; 
                                pos <= 0;
                                state <= s_skip;
                            end else begin
                                pos <= 0;
                                state <= s_idle;
                            end
                        end
                    end
                end
                
                s_skip: begin
                    if (block_length == 16'd1) begin
                        pos <= 0;
                        state <= s_idle;
                    end else begin
                        block_length <= block_length - 16'd1;
                    end
                end
                
                default: state <= s_idle;
            endcase
        end
    end
end
endmodule
