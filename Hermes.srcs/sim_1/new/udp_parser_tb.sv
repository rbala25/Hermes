`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/20/2026 05:16:13 PM
// Design Name: 
// Module Name: udp_parser_tb
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


module udp_parser_tb();

logic clk, rst;
logic payload_valid;
logic ip_header_valid;
logic ip_payload_done;
logic error;
logic [7:0] ip_protocol;
logic [7:0] payload_data;
logic [31:0] ip_src;
logic [31:0] ip_dest;

logic [15:0] udp_src;
logic [15:0] udp_dest;
logic [15:0] udp_length;
logic [15:0] udp_checksum;
logic udp_header_valid;
logic udp_checksum_val;
logic [7:0] udp_payload;
logic udp_payload_valid;
logic udp_payload_done;
logic udp_error;

udp_parser dut (
    .clk(clk),
    .rst(rst),
    .payload_valid(payload_valid),
    .ip_header_valid(ip_header_valid),
    .ip_payload_done(ip_payload_done),
    .error(error),
    .ip_protocol(ip_protocol),
    .payload_data(payload_data),
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

initial clk = 0;
always #20 clk = ~clk;

task send_byte(input [7:0] b, input last);
    @(negedge clk);
    payload_data  = b;
    payload_valid = 1;
    ip_payload_done = last;
    @(posedge clk); #1;
    payload_valid = 0;
    ip_payload_done = 0;
endtask

//src ip: 192.168.1.10 
//dest ip: 192.168.1.20 
//src port:1234 
//dest port:5678
//payload: "HI" 
//length: 10
initial begin
    // init
    rst = 1;
    payload_valid = 0;
    ip_header_valid = 0;
    ip_payload_done = 0;
    error = 0;
    ip_protocol = 0;
    payload_data = 0;
    ip_src  = 32'hC0A8010A;
    ip_dest = 32'hC0A80114;
    repeat(4) @(posedge clk);
    rst = 0;
    @(posedge clk);

    $display("--- TEST 1: valid packet ---");
    
    @(negedge clk);
    ip_protocol = 8'h11;
    ip_header_valid = 1;
    @(posedge clk); #1;
    ip_header_valid = 0;

    send_byte(8'h04, 0);
    send_byte(8'hD2, 0);

    send_byte(8'h16, 0);
    send_byte(8'h2E, 0);
    send_byte(8'h00, 0);
    send_byte(8'h0A, 0);


    // for this tb we use 0x0000 to guarantee pass
    send_byte(8'h00, 0);
    send_byte(8'h00, 0);


    send_byte(8'h48, 0);
    send_byte(8'h49, 1);

    @(posedge clk);
    @(posedge clk);

    if (udp_src == 16'h04D2)
        $display("PASS: src port correct (0x%04X)", udp_src);
    else
        $display("FAIL: src port wrong, got 0x%04X", udp_src);

    if (udp_dest == 16'h162E)
        $display("PASS: dst port correct (0x%04X)", udp_dest);
    else
        $display("FAIL: dst port wrong, got 0x%04X", udp_dest);

    if (udp_length == 16'h000A)
        $display("PASS: length correct (0x%04X)", udp_length);
    else
        $display("FAIL: length wrong, got 0x%04X", udp_length);

    if (udp_checksum_val)
        $display("PASS: checksum valid");
    else
        $display("FAIL: checksum invalid");




    $display("--- TEST 2: error mid packet ---");
    repeat(5) @(posedge clk);

    @(negedge clk);
    ip_protocol = 8'h11;
    ip_header_valid = 1;
    @(posedge clk); #1;
    ip_header_valid = 0;

    send_byte(8'h04, 0);
    send_byte(8'hD2, 0);

    @(negedge clk);
    error = 1;
    @(posedge clk); #1;
    error = 0;

    @(posedge clk);
    if (udp_error)
        $display("PASS: error flagged");
    else
        $display("FAIL: error not flagged");

    if (dut.state == 0)
        $display("PASS: returned to idle");
    else
        $display("FAIL: not in idle, state = %0d", dut.state);


    $display("--- TEST 3: non-UDP protocol ignored ---");
    repeat(5) @(posedge clk);

    @(negedge clk);
    ip_protocol = 8'h06; 
    ip_header_valid = 1;
    @(posedge clk); #1;
    ip_header_valid = 0;

    send_byte(8'hAA, 0);
    send_byte(8'hBB, 0);

    @(posedge clk);
    if (dut.state == 0)
        $display("PASS: stayed idle for non-UDP");
    else
        $display("FAIL: entered parse for non-UDP, state = %0d", dut.state);

    $display("--- done ---");
    $finish;
end
endmodule
