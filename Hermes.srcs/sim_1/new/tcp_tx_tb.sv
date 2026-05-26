`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 07:18:52 PM
// Design Name: 
// Module Name: tcp_tx_tb
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


module tcp_tx_tb;
logic tx_clk = 0;
always #20 tx_clk = ~tx_clk;

logic rst;
logic [31:0] src_ip, dst_ip;
logic [15:0] tcp_length;
logic [15:0] src_port, dst_port;
logic [31:0] ack_num;
logic [7:0] flags;
logic [15:0] window_size;
logic [15:0] payload_csum;
logic [31:0] init_seq;
logic load_seq;
logic start;
logic done;
logic [7:0] payload_in_data;
logic payload_in_valid;
logic payload_in_ready;
logic [7:0] payload_data;
logic payload_valid;
logic payload_ready;

tcp_tx dut(
    .tx_clk(tx_clk),
    .rst(rst),
    .src_ip(src_ip),
    .dst_ip(dst_ip),
    .tcp_length(tcp_length),
    .src_port(src_port),
    .dst_port(dst_port),
    .ack_num(ack_num),
    .flags(flags),
    .window_size(window_size),
    .payload_csum(payload_csum),
    .init_seq(init_seq),
    .load_seq(load_seq),
    .start(start),
    .done(done),
    .payload_in_data(payload_in_data),
    .payload_in_valid(payload_in_valid),
    .payload_in_ready(payload_in_ready),
    .payload_data(payload_data),
    .payload_valid(payload_valid),
    .payload_ready(payload_ready)
);

assign payload_ready = 1; //ip_tx is always ready

int cap_idx = 0;
logic [7:0] cap[0:511];
always @(posedge tx_clk) begin
    if (payload_valid && payload_ready) begin
        cap[cap_idx] = payload_data;
        cap_idx = cap_idx + 1;
    end
end

int plen = 0;
int pidx = 0;
logic [7:0] pbuf[0:31];
assign payload_in_valid = (pidx < plen);
assign payload_in_data = pbuf[pidx];
always @(negedge tx_clk) begin
    if (payload_in_ready && (pidx < plen)) pidx = pidx + 1;
end
int errors = 0;

task check_byte;
    input int idx;
    input logic [7:0] expected;
    input string field;
    if (cap[idx] !== expected) begin
        $error("FAIL %s: cap[%0d] = 0x%02X, expected 0x%02X", field, idx, cap[idx], expected);
        errors++;
    end else
        $display("  pass %-22s cap[%0d] = 0x%02X", field, idx, cap[idx]);
endtask

task check_checksum_valid; //psuedo header reconstruction
    input int seg_start;
    input int seg_len;
    input logic [31:0] t_src_ip, t_dst_ip;
    input logic [15:0] t_tcp_len;
    logic [31:0] s;
    logic [16:0] f;
    logic [15:0] r;
    int i;
    s = 0;
    //pseudo-header
    s += {16'h0, t_src_ip[31:16]};
    s += {16'h0, t_src_ip[15:0]};
    s += {16'h0, t_dst_ip[31:16]};
    s += {16'h0, t_dst_ip[15:0]};
    s += 32'h0006;
    s += {16'h0, t_tcp_len};

    for (i = 0; i < seg_len; i += 2) begin
        if (i + 1 < seg_len)
            s += {16'h0, cap[seg_start + i], cap[seg_start + i + 1]};
        else
            s += {16'h0, cap[seg_start + i], 8'h00}; //odd-length zero-pad
    end

    f = {1'b0, s[15:0]} + {1'b0, s[31:16]};
    r = f[15:0] + {15'h0, f[16]};
    if (r !== 16'hFFFF) begin
        $error("FAIL checksum: pseudo+segment folded sum = 0x%04X (expected 0xFFFF)", r);
        errors++;
    end else
        $display("  pass checksum: pseudo+segment sum folds to 0xFFFF");
endtask

initial begin
    src_ip = 32'hC0A80001; 
    dst_ip = 32'hC0A80002; 
    src_port = 16'd12345;
    dst_port = 16'd1234; 
    ack_num = 32'hDEADBEEF;
    window_size = 16'hFFFF;
    init_seq = 32'h12345678;
    tcp_length = 16'd20;
    payload_csum = 16'h0;
    flags = 8'h10;
    load_seq = 0;
    start = 0;
    rst = 1;

    repeat(4) @(posedge tx_clk);
    rst = 0;

    @(posedge tx_clk); #1;
    load_seq = 1;
    @(posedge tx_clk); #1;
    load_seq = 0;
    @(posedge tx_clk); #1;


    //test 1
    $display("=== Test 1: PSH+ACK 8-byte payload (seq=0x12345678) ===");
    flags = 8'h18; //PSH+ACK
    tcp_length = 16'd28; //20 header + 8 payload
    payload_csum = 16'hA1A3;
    pbuf[0]=8'hDE; pbuf[1]=8'hAD; pbuf[2]=8'hBE; pbuf[3]=8'hEF;
    pbuf[4]=8'h01; pbuf[5]=8'h02; pbuf[6]=8'h03; pbuf[7]=8'h04;
    plen = 8; pidx = 0; cap_idx = 0;

    start = 1;
    @(posedge tx_clk); #1;
    start = 0;

    @(posedge done);
    @(posedge tx_clk);

    check_byte(0,  8'h30, "src_port[15:8]");
    check_byte(1,  8'h39, "src_port[7:0]");
    check_byte(2,  8'h04, "dst_port[15:8]");
    check_byte(3,  8'hD2, "dst_port[7:0]");
    check_byte(4,  8'h12, "seq[31:24]");
    check_byte(5,  8'h34, "seq[23:16]");
    check_byte(6,  8'h56, "seq[15:8]");
    check_byte(7,  8'h78, "seq[7:0]");
    check_byte(8,  8'hDE, "ack[31:24]");
    check_byte(9,  8'hAD, "ack[23:16]");
    check_byte(10, 8'hBE, "ack[15:8]");
    check_byte(11, 8'hEF, "ack[7:0]");
    check_byte(12, 8'h50, "data_offset/reserved");
    check_byte(13, 8'h18, "flags PSH+ACK");
    check_byte(14, 8'hFF, "window[15:8]");
    check_byte(15, 8'hFF, "window[7:0]");
    check_byte(16, 8'h51, "checksum[15:8]");
    check_byte(17, 8'h78, "checksum[7:0]");
    check_byte(18, 8'h00, "urgent[15:8]");
    check_byte(19, 8'h00, "urgent[7:0]");
    check_byte(20, 8'hDE, "payload[0]");
    check_byte(21, 8'hAD, "payload[1]");
    check_byte(22, 8'hBE, "payload[2]");
    check_byte(23, 8'hEF, "payload[3]");
    check_byte(24, 8'h01, "payload[4]");
    check_byte(25, 8'h02, "payload[5]");
    check_byte(26, 8'h03, "payload[6]");
    check_byte(27, 8'h04, "payload[7]");
    check_checksum_valid(0, 28, src_ip, dst_ip, tcp_length);
    if (cap_idx !== 28) begin
        $error("FAIL byte count: got %0d, expected 28", cap_idx); errors++;
    end else
        $display("  pass byte count: 28");

    //test 2
    $display("=== Test 2: Pure ACK (seq should be 0x12345680) ===");
    flags = 8'h10; //ACK only
    tcp_length = 16'd20;
    payload_csum = 16'h0;
    plen = 0; pidx = 0; cap_idx = 0;

    @(posedge tx_clk); #1;
    start = 1;
    @(posedge tx_clk); #1;
    start = 0;

    @(posedge done);
    @(posedge tx_clk);

    check_byte(4, 8'h12, "seq[31:24] after +8");
    check_byte(5, 8'h34, "seq[23:16] after +8");
    check_byte(6, 8'h56, "seq[15:8]  after +8");
    check_byte(7, 8'h80, "seq[7:0]   0x78+8=0x80");
    check_byte(16, 8'hF3, "checksum[15:8]");
    check_byte(17, 8'h23, "checksum[7:0]");
    check_checksum_valid(0, 20, src_ip, dst_ip, tcp_length);
    if (cap_idx !== 20) begin
        $error("FAIL byte count: got %0d, expected 20", cap_idx); errors++;
    end else
        $display("  pass byte count: 20");

    //test 3
    $display("=== Test 3: Second pure ACK (seq must still be 0x12345680) ===");
    cap_idx = 0;

    @(posedge tx_clk); #1;
    start = 1;
    @(posedge tx_clk); #1;
    start = 0;

    @(posedge done);
    @(posedge tx_clk);

    check_byte(4, 8'h12, "seq[31:24] unchanged");
    check_byte(5, 8'h34, "seq[23:16] unchanged");
    check_byte(6, 8'h56, "seq[15:8]  unchanged");
    check_byte(7, 8'h80, "seq[7:0]   unchanged");
    check_checksum_valid(0, 20, src_ip, dst_ip, tcp_length);

    $display("=== Summary ===");
    if (errors == 0)
        $display("ALL TESTS PASSED");
    else
        $display("FAILED: %0d error(s)", errors);

    $finish;
end


endmodule
