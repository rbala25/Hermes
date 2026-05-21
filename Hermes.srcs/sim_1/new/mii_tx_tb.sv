`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 01:55:33 AM
// Design Name: 
// Module Name: mii_tx_tb
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

module mii_tx_tb();

logic tx_clk;
logic rst;
logic [7:0] data;
logic valid;
logic ready;
logic [3:0] txd;
logic tx_en;
 
mii_tx dut(
    .tx_clk(tx_clk),
    .rst(rst),
    .data(data),
    .valid(valid),
    .ready(ready),
    .txd(txd),
    .tx_en(tx_en)
);
 
always #20 tx_clk = ~tx_clk;
 
logic [3:0] nibbles[$];
int fail_count = 0;
int ready_count;
 
task check(input string name, input logic got, input logic exp);
    if(got !== exp) begin
        $display("FAIL %s: got %0b expected %0b", name, got, exp);
        fail_count++;
    end else $display("PASS %s", name);
endtask
 
task check_vec(input string name, input logic [3:0] got, input logic [3:0] exp);
    if(got !== exp) begin
        $display("FAIL %s: got %0h expected %0h", name, got, exp);
        fail_count++;
    end else $display("PASS %s", name);
endtask
 
always @(posedge tx_clk) begin
    if(tx_en) nibbles.push_back(txd);
    if(ready) begin
        ready_count <= ready_count + 1;
        case(ready_count)
            0: data <= 8'hCD; //second byte
            1: valid <= 0;    //no more bytes
        endcase
    end
end
 
initial begin
    tx_clk = 0;
    rst = 1;
    valid = 0;
    data = 0;
    ready_count = 0;
    repeat(4) @(posedge tx_clk);
    rst = 0;
    @(posedge tx_clk);
 
    data = 8'hAB;
    valid = 1;
 
    repeat(40) @(posedge tx_clk);
 
    $display("\n=== Test 1: preamble and SFD ===");
    check("preamble nibble 0",  nibbles[0],  4'h5);
    check("preamble nibble 7",  nibbles[7],  4'h5);
    check("preamble nibble 14", nibbles[14], 4'h5);
    check("SFD high nibble",    nibbles[15], 4'hD);
 
    $display("\n=== Test 2: data bytes ===");
    check_vec("byte0 low",  nibbles[16], 4'hB);
    check_vec("byte0 high", nibbles[17], 4'hA);
    check_vec("byte1 low",  nibbles[18], 4'hD);
    check_vec("byte1 high", nibbles[19], 4'hC);
 
    $display("\n=== Test 3: tx_en dropped ===");
    check("tx_en low after frame", tx_en, 1'b0);
 
    $display("\n=============================");
    if(fail_count == 0) $display("All tests PASSED");
    else $display("%0d test(s) FAILED", fail_count);
    $display("=============================\n");
 
    $finish;
end
endmodule
