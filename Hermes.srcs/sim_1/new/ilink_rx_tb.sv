`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/28/2026 12:27:00 AM
// Design Name: 
// Module Name: ilink_rx_tb
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


module ilink_rx_tb;
 
logic clk, rst;
logic [7:0] payload_data;
logic payload_valid, payload_ready;
logic neg_response, estab_ack, session_error;
logic [383:0] reject_reason;
logic [31:0] next_seq_no, rx_next_seq_no;
logic send_sequence;
logic [63:0] bid_order_id, ask_order_id;
logic exec_new, exec_reject, exec_elimination, exec_trade;
logic exec_modify, exec_cancel, unsolicited_cancel, ocr_reject, business_reject;
logic gap_detected;
logic [31:0] gap_from_seq, gap_count;
logic signed [63:0] fill_price;
logic [31:0] fill_qty, fill_leaves_qty, fill_cum_qty;
logic [7:0] fill_side;
logic [159:0] fill_clord_id;
logic [319:0] exec_id;
logic [15:0] ord_rej_reason, cxl_rej_reason;
logic [63:0] order_id_out;
logic [15:0] biz_rej_reason;
logic [2047:0] biz_text;
 
ilink_rx dut(
    .clk(clk), .rst(rst),
    .payload_data(payload_data), .payload_valid(payload_valid), .payload_ready(payload_ready),
    .neg_response(neg_response), .estab_ack(estab_ack), .session_error(session_error),
    .reject_reason(reject_reason), .next_seq_no(next_seq_no), .rx_next_seq_no(rx_next_seq_no),
    .send_sequence(send_sequence), .bid_order_id(bid_order_id), .ask_order_id(ask_order_id),
    .exec_new(exec_new), .exec_reject(exec_reject), .exec_elimination(exec_elimination),
    .exec_trade(exec_trade), .exec_modify(exec_modify), .exec_cancel(exec_cancel),
    .unsolicited_cancel(unsolicited_cancel), .ocr_reject(ocr_reject), .business_reject(business_reject),
    .gap_detected(gap_detected), .gap_from_seq(gap_from_seq), .gap_count(gap_count),
    .fill_price(fill_price), .fill_qty(fill_qty), .fill_leaves_qty(fill_leaves_qty),
    .fill_cum_qty(fill_cum_qty), .fill_side(fill_side), .fill_clord_id(fill_clord_id),
    .exec_id(exec_id), .ord_rej_reason(ord_rej_reason), .cxl_rej_reason(cxl_rej_reason),
    .order_id_out(order_id_out), .biz_rej_reason(biz_rej_reason), .biz_text(biz_text)
);
 
initial clk = 0;
always #20 clk = ~clk;
 
int pass_cnt;
int fail_cnt;
 

logic [7:0] fbuf [0:599];
int fbuf_len;
 
task automatic send_byte(input logic [7:0] b);
    @(negedge clk);
    payload_data = b;
    payload_valid = 1;
    @(posedge clk); #1;
    @(negedge clk);
    payload_valid = 0;
endtask
 
task automatic flush_frame();
    for (int i = 0; i < fbuf_len; i++) send_byte(fbuf[i]);
endtask

task automatic tick();
    @(posedge clk); #1;
endtask
 
task automatic check(input string name, input logic cond);
    if (cond) begin $display("PASS: %s", name); pass_cnt++; end
    else begin $display("FAIL: %s", name); fail_cnt++; end
endtask

task automatic init_frame(input int flen, input int blk_len, input int tmpl_id);
    fbuf_len = flen;
    fbuf[0] = flen[7:0]; fbuf[1] = flen[15:8];
    fbuf[2] = 8'hCA;     fbuf[3] = 8'hFE;
    fbuf[4] = blk_len[7:0]; fbuf[5] = blk_len[15:8];
    fbuf[6] = tmpl_id[7:0]; fbuf[7] = tmpl_id[15:8];
    fbuf[8] = 8'd8; fbuf[9] = 8'd0;
    fbuf[10] = 8'd8; fbuf[11] = 8'd0;
    for (int i = 12; i < flen; i++) fbuf[i] = 8'h00;
endtask
 

task automatic f8(input int pos, input logic [7:0] v);  fbuf[pos] = v; endtask
task automatic f16(input int pos, input logic [15:0] v);
    fbuf[pos]=v[7:0]; fbuf[pos+1]=v[15:8]; endtask
task automatic f32(input int pos, input logic [31:0] v);
    fbuf[pos]=v[7:0]; fbuf[pos+1]=v[15:8]; fbuf[pos+2]=v[23:16]; fbuf[pos+3]=v[31:24]; endtask
task automatic f64(input int pos, input logic [63:0] v);
    fbuf[pos]=v[7:0]; fbuf[pos+1]=v[15:8]; fbuf[pos+2]=v[23:16]; fbuf[pos+3]=v[31:24];
    fbuf[pos+4]=v[39:32]; fbuf[pos+5]=v[47:40]; fbuf[pos+6]=v[55:48]; fbuf[pos+7]=v[63:56]; endtask

function automatic int bp(input int body_off); return body_off + 12; endfunction
 
task automatic do_reset();
    rst = 1; payload_valid = 0; payload_data = 0;
    repeat(4) @(posedge clk); #1;
    rst = 0;
    @(posedge clk); #1;
endtask
 
task automatic test_neg_response();
    $display("\n--- Test 1+2: NegotiationResponse (501) templateID parse ---");
    init_frame(12, 0, 501); 
    flush_frame();
    tick(); //dispatch pending fires
    #1;
    check("templateID 501 / neg_response pulse", neg_response);
endtask

task automatic test_estab_ack(input logic [31:0] nsn);
    $display("\n--- Test 3: EstablishmentAck (504) next_seq_no=%0d ---", nsn);
    init_frame(12+20, 20, 504);
    f32(bp(16), nsn);
    flush_frame();
    tick(); #1;
    check("estab_ack pulse", estab_ack);
    check("next_seq_no correct", next_seq_no == nsn);
endtask
 

task automatic test_exec_new_buy();
    logic [63:0] exp_oid = 64'hCAFEBABE_12345678;
    logic signed [63:0] exp_px = 64'd50_000_000_000;
    $display("\n--- Test 4: ExecutionReportNew (522) Buy ---");
    init_frame(12+226, 226, 522);
    f32(bp(0), 32'd1); 
    f64(bp(100), exp_oid);  
    f64(bp(108), exp_px); 
    f8(bp(190), 8'd1);       
    flush_frame();
    tick(); #1;
    check("exec_new pulse (buy)", exec_new);
    check("order_id_out", order_id_out == exp_oid);
    check("fill_price", fill_price == exp_px);
    check("fill_side (buy=1)", fill_side == 8'd1);
    check("bid_order_id updated", bid_order_id == exp_oid);
endtask
 

task automatic test_exec_new_sell();
    logic [63:0] exp_oid = 64'hFEEDFACE_ABCD1234;
    $display("\n--- Test 4b: ExecutionReportNew (522) Sell ---");
    init_frame(12+226, 226, 522);
    f32(bp(0), 32'd2);
    f64(bp(100), exp_oid);
    f8(bp(190), 8'd2);
    flush_frame();
    tick(); #1;
    check("exec_new pulse (sell)", exec_new);
    check("ask_order_id updated", ask_order_id == exp_oid);
endtask
 

task automatic test_exec_trade();
    logic signed [63:0] exp_lpx = 64'd48_000_000_000;
    logic [31:0] exp_lqty = 32'd5;
    logic [31:0] exp_lv = 32'd3;
    logic [31:0] exp_cum = 32'd7;
    $display("\n--- Test 5: ExecutionReportTradeOutright (525) ---");
    init_frame(12+293, 293, 525);
    f32(bp(0), 32'd3);
    f64(bp(100), exp_lpx);
    f32(bp(193), exp_lqty);
    f32(bp(197), exp_cum);
    f32(bp(213), exp_lv);
    f8(bp(223), 8'd1);
    flush_frame();
    tick(); #1;
    check("exec_trade pulse", exec_trade);
    check("fill_price=LastPx", fill_price == exp_lpx);
    check("fill_qty=LastQty", fill_qty == exp_lqty);
    check("fill_leaves_qty", fill_leaves_qty == exp_lv);
    check("fill_cum_qty", fill_cum_qty == exp_cum);
endtask
 
task automatic test_exec_cancel();
    $display("\n--- Test 6a: ExecReportCancel solicited (534) ---");
    init_frame(12+247, 247, 534);
    f32(bp(0), 32'd4);
    f8(bp(199), 8'hFF); //null = solicited
    flush_frame();
    tick(); #1;
    check("exec_cancel (solicited)", exec_cancel);
    check("no unsolicited_cancel", !unsolicited_cancel);
 
    $display("\n--- Test 6b: ExecReportCancel unsolicited (534) ---");
    init_frame(12+247, 247, 534);
    f32(bp(0), 32'd5);
    f8(bp(199), 8'h01); //non-null = unsolicited
    flush_frame();
    tick(); #1;
    check("exec_cancel (unsolicited)", exec_cancel);
    check("unsolicited_cancel fired", unsolicited_cancel);
endtask

task automatic test_gap();
    $display("\n--- Test 7: Gap detection ---");
    init_frame(12+226, 226, 522);
    f32(bp(0), 32'd10); 
    f8(bp(190), 8'd1);
    flush_frame();
    tick(); #1;
    check("gap_detected", gap_detected);
    check("gap_from_seq=6", gap_from_seq == 32'd6);
    check("gap_count=4", gap_count == 32'd4);
endtask
 
task automatic test_exec_reject();
    logic [15:0] exp_rjr = 16'd99;
    $display("\n--- Test 8: ExecutionReportReject (523) ---");
    init_frame(12+483, 483, 523);
    f32(bp(0), 32'd11);
    f16(bp(441), exp_rjr);
    f8(bp(448), 8'd2);
    flush_frame();
    tick(); #1;
    check("exec_reject pulse", exec_reject);
    check("ord_rej_reason correct", ord_rej_reason == exp_rjr);
    check("fill_side (reject sell)", fill_side == 8'd2);
endtask
 
initial begin
    pass_cnt = 0; fail_cnt = 0;
    $display("=== ilink_rx testbench ===");
 
    do_reset();
    test_neg_response();
 
    do_reset();
    test_estab_ack(32'hDEAD_BEEF); 
 
    do_reset();
    test_estab_ack(32'd1);
 
    test_exec_new_buy();   
    test_exec_new_sell();  
    test_exec_trade();    
    test_exec_cancel();     
    test_gap();
    test_exec_reject();
 
    repeat(5) @(posedge clk);
    $display("\n=== Results: %0d passed, %0d failed ===", pass_cnt, fail_cnt);
    if (fail_cnt == 0) $display("ALL TESTS PASSED");
    $finish;
end
 
initial begin #20_000_000; $display("TIMEOUT"); $finish; end
endmodule
