`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:47:23 PM
// Design Name: 
// Module Name: eth_parser_tb
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


module eth_parser_tb;
 
logic clk = 0;
logic rst;
logic [47:0] dest_mac;
logic [47:0] src_mac;
logic [15:0] ether_type;
logic header_valid;
logic [7:0] payload_data;
logic payload_valid;
logic frame_done;
logic error;
logic [7:0] data;
logic valid;
logic frame_active;
 
eth_parser dut (.dest_mac(dest_mac), .src_mac(src_mac), .ether_type(ether_type), .header_valid(header_valid), .payload_data(payload_data),
    .payload_valid(payload_valid), .frame_done(frame_done), .error(error), .clk(clk), .rst(rst), .data(data), .valid(valid), .frame_active(frame_active));
 
always #20 clk = ~clk;
 
logic [7:0] rx_payload[$]; //dynamic array specified with $
always_ff @(posedge clk)
    if (payload_valid) rx_payload.push_back(payload_data);
 
logic error_seen = 0; //error latch
always_ff @(posedge clk)
    if (error) error_seen <= 1;
 
task automatic send_byte(input logic [7:0] b);
    @(posedge clk); #1;
    data = b;
    valid = 1;
    frame_active = 1;
    @(posedge clk); #1;
    valid = 0;
endtask
 
task automatic send_frame(input logic [47:0] dst, input logic [47:0] src, input logic [15:0] etype, input logic [7:0] payload[], input logic [31:0] fcs);
    @(posedge clk); #1;
    frame_active = 1;
    valid = 0;
    for (int i = 5; i >= 0; i--) send_byte(dst[i*8 +: 8]); //dst mac
    for (int i = 5; i >= 0; i--) send_byte(src[i*8 +: 8]); //src mac
    send_byte(etype[15:8]);
    send_byte(etype[7:0]);
    foreach (payload[i]) send_byte(payload[i]);
    send_byte(fcs[31:24]); //4 fcs bytes
    send_byte(fcs[23:16]);
    send_byte(fcs[15:8]);
    send_byte(fcs[7:0]);
    @(posedge clk); #1;
    frame_active = 0;
    valid = 0;
    repeat(4) @(posedge clk);
endtask
 
int fail_count = 0;
 
task check(input string name, input logic got, input logic expected);
    if (got !== expected) begin
        $display("FAIL [%s]: got %h, expected %h", name, got, expected);
        fail_count++;
    end else
        $display("PASS [%s]", name);
endtask
 
task check_vec(input string name, input logic [47:0] got, input logic [47:0] expected);
    if (got !== expected) begin
        $display("FAIL [%s]: got %h, expected %h", name, got, expected);
        fail_count++;
    end else
        $display("PASS [%s]: %h", name, got);
endtask
 
initial begin
    $dumpfile("eth_parser_tb.vcd");
    $dumpvars(0, eth_parser_tb);
    rst = 1;
    valid = 0;
    frame_active = 0;
    data = 0;
    repeat(16) @(posedge clk);
    @(posedge clk); #1;
    rst = 0;
    repeat(2) @(posedge clk);
 
    //test 1: normal IPv4 frame
    //dst=FF:FF:FF:FF:FF:FF, src=DE:AD:BE:EF:00:01, ethertype=0x0800, payload=DE AD BE EF CA FE
    $display("\n=== Test 1: normal frame ===");
    rx_payload = '{};
    begin //scope needed for automatic vars
        automatic logic [7:0] pl[] = '{8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE};
        send_frame(48'hFFFFFFFFFFFF, 48'hDEADBEEF0001, 16'h0800, pl, 32'hDEADBEEF);
    end
    check_vec("dst_mac", dest_mac, 48'hFFFFFFFFFFFF);
    check_vec("src_mac", src_mac, 48'hDEADBEEF0001);
    check_vec("ethertype", {16'h0, ether_type}, {16'h0, 16'h0800});
    if (rx_payload.size() !== 6) begin
        $display("FAIL [payload_count]: got %0d, expected 6", rx_payload.size());
        fail_count++;
    end else begin
        $display("PASS [payload_count]: 6 bytes");
        begin
            automatic logic [7:0] expected[] = '{8'hDE, 8'hAD, 8'hBE, 8'hEF, 8'hCA, 8'hFE};
            for (int i = 0; i < 6; i++) begin
                if (rx_payload[i] !== expected[i]) begin
                    $display("FAIL [payload[%0d]]: got %h, expected %h", i, rx_payload[i], expected[i]);
                    fail_count++;
                end
            end
            if (fail_count == 0) $display("PASS [payload bytes match]");
        end
    end
    repeat(4) @(posedge clk);
 
    //test 2, ethertype=0x0806
    $display("\n=== Test 2: ARP frame ===");
    rx_payload = '{};
    begin
        automatic logic [7:0] pl[] = '{8'h00, 8'h01, 8'h08, 8'h00, 8'h06, 8'h04, 8'h00, 8'h01};
        send_frame(48'hFFFFFFFFFFFF, 48'hAABBCCDDEEFF, 16'h0806, pl, 32'h0);
    end
    check_vec("dst_mac", dest_mac, 48'hFFFFFFFFFFFF);
    check_vec("src_mac", src_mac, 48'hAABBCCDDEEFF);
    check_vec("ethertype", {16'h0, ether_type}, {16'h0, 16'h0806});
    repeat(4) @(posedge clk);
 
    //test 3
    $display("\n=== Test 3: back-to-back frames ===");
    rx_payload = '{};
    begin
        automatic logic [7:0] pl1[] = '{8'hAA, 8'hBB};
        automatic logic [7:0] pl2[] = '{8'hCC, 8'hDD};
        send_frame(48'h112233445566, 48'hAABBCCDDEEFF, 16'h0800, pl1, 32'h0);
        send_frame(48'h665544332211, 48'hFFEEDDCCBBAA, 16'h0800, pl2, 32'h0);
    end
    check_vec("dst_mac (frame 2)", dest_mac, 48'h665544332211);
    check_vec("src_mac (frame 2)", src_mac, 48'hFFEEDDCCBBAA);
    repeat(4) @(posedge clk);
 
    //test 4: mid-header abort
    $display("\n=== Test 4: mid-header abort ===");
    @(posedge clk); #1; error_seen = 0; //clear latch
    @(posedge clk); #1;
    frame_active = 1;
    valid = 0;
    send_byte(8'hFF);
    send_byte(8'hFF);
    @(posedge clk); #1;
    frame_active = 0;
    valid = 0;
    repeat(4) @(posedge clk);
    check("error flag set", error_seen, 1'b1);
    check("frame_done not set", frame_done, 1'b0);
 
    $display("\n=============================");
    if (fail_count == 0)
        $display("All tests PASSED");
    else
        $display("%0d test(s) FAILED", fail_count);
    $display("=============================\n");
 
    $finish;
end
 
endmodule