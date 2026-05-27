module tcp_session_tb;
localparam RETRANSMIT_CYCLES = 20;
localparam KEEPALIVE_CYCLES = 30;
 
logic clk, rst;
logic connect, disconnect;
logic [15:0] src_port, dst_port, window_size;
logic [31:0] isn;
logic rx_syn, rx_ack, rx_fin, rx_rst;
logic [31:0] rx_seq_num;
logic header_valid;
logic ctrl_start;
logic [7:0] ctrl_flags;
logic [31:0] ctrl_ack_num;
logic [15:0] ctrl_tcp_length, ctrl_payload_csum;
logic tx_done;
logic load_seq;
logic [31:0] init_seq;
logic tx_grant;
logic established, closed;
 
tcp_session #(
    .RETRANSMIT_CYCLES(RETRANSMIT_CYCLES),
    .KEEPALIVE_CYCLES(KEEPALIVE_CYCLES)
) dut (
    .clk(clk),
    .rst(rst),
    .connect(connect),
    .disconnect(disconnect),
    .src_port(src_port),
    .dst_port(dst_port),
    .window_size(window_size),
    .isn(isn),
    .rx_syn(rx_syn),
    .rx_ack(rx_ack),
    .rx_fin(rx_fin),
    .rx_rst(rx_rst),
    .rx_seq_num(rx_seq_num),
    .header_valid(header_valid),
    .ctrl_start(ctrl_start),
    .ctrl_flags(ctrl_flags),
    .ctrl_ack_num(ctrl_ack_num),
    .ctrl_tcp_length(ctrl_tcp_length),
    .ctrl_payload_csum(ctrl_payload_csum),
    .tx_done(tx_done),
    .load_seq(load_seq),
    .init_seq(init_seq),
    .tx_grant(tx_grant),
    .established(established),
    .closed(closed)
);
 
always #5 clk = ~clk;
 
task send_header(input logic syn, ack, fin, input logic [31:0] seq);
    rx_syn = syn; rx_ack = ack; rx_fin = fin;
    rx_seq_num = seq;
    header_valid = 1;
    @(posedge clk); #1;
    header_valid = 0;
    rx_syn = 0; rx_ack = 0; rx_fin = 0;
endtask
 
task tick(input int n);
    repeat(n) @(posedge clk); #1;
endtask
 
task wait_ctrl_start; 
    @(posedge clk iff ctrl_start); #1;
endtask
 
task complete_tx;
    @(posedge clk); #1; //ctrl start seen, tx busy goes high next cycle
    tx_done = 1;
    @(posedge clk); #1;
    tx_done = 0;
endtask
 
initial begin
    clk = 0; rst = 1;
    connect = 0; disconnect = 0;
    src_port = 16'h1234; dst_port = 16'h0699;
    window_size = 16'hFFFF;
    isn = 32'hDEAD_0000;
    rx_syn = 0; rx_ack = 0; rx_fin = 0; rx_rst = 0;
    rx_seq_num = 0;
    header_valid = 0;
    tx_done = 0;
 
    tick(3);
    rst = 0;
    tick(2);
 
    $display("TEST 1: three-way handshake");
    connect = 1; @(posedge clk); #1; connect = 0;
    assert(ctrl_start) else $error("SYN not sent");
    assert(ctrl_flags == 8'h02) else $error("wrong flags for SYN: %h", ctrl_flags);
    assert(load_seq) else $error("load_seq not pulsed");
    complete_tx();
 
    send_header(1, 1, 0, 32'd100);
    assert(ctrl_start) else $error("ACK not sent after SYN-ACK");
    assert(ctrl_flags == 8'h10) else $error("wrong flags for ACK: %h", ctrl_flags);
    assert(ctrl_ack_num == 32'd101) else $error("wrong ack_num: %0d", ctrl_ack_num);
    complete_tx();
    tick(1);
    assert(established) else $error("not established after handshake");
    $display("PASS: handshake");
 
    $display("TEST 2: keepalive");
    wait_ctrl_start(); 
    assert(ctrl_flags == 8'h10) else $error("wrong flags for keepalive: %h", ctrl_flags);
    complete_tx();
    $display("PASS: keepalive");
 
    $display("TEST 3: SYN retransmit");
    disconnect = 1; @(posedge clk); #1; disconnect = 0;
    complete_tx();
    tick(5);
    rst = 1; tick(2); rst = 0; tick(2);
    connect = 1; @(posedge clk); #1; connect = 0;
    complete_tx();
    wait_ctrl_start(); 
    assert(ctrl_flags == 8'h02) else $error("wrong flags on retransmit: %h", ctrl_flags);
    $display("PASS: SYN retransmit");
 
    $display("TEST 4: rx_rst");
    complete_tx();
    send_header(1, 1, 0, 32'd200);
    complete_tx();
    tick(1);
    assert(established) else $error("not established");
    rx_rst = 1; @(posedge clk); #1; rx_rst = 0;
    tick(1);
    assert(!established) else $error("still established after RST");
    assert(closed) else $error("not closed after RST");
    $display("PASS: rx_rst");
 
    $display("TEST 5: remote FIN");
    tick(2);
    connect = 1; @(posedge clk); #1; connect = 0;
    complete_tx();
    send_header(1, 1, 0, 32'd300);
    complete_tx();
    tick(1);
    assert(established) else $error("not established");
    send_header(0, 0, 1, 32'd301); //CME sends fin
    assert(ctrl_start) else $error("FIN+ACK not sent");
    assert(ctrl_flags == 8'h11) else $error("wrong flags: %h", ctrl_flags);
    complete_tx();
    tick(1);
    send_header(0, 1, 0, 32'd302); //CME acks our fin
    tick(1);
    assert(!established) else $error("still established in TIME_WAIT");
    $display("PASS: remote FIN");
 
    $display("ALL TESTS PASSED");
    $finish;
end
 
initial begin
    #10000;
    $error("TIMEOUT");
    $finish;
end
endmodule