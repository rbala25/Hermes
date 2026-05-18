`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Ba;a
// 
// Create Date: 05/18/2026 01:18:45 PM
// Design Name: 
// Module Name: mii_rx_tb
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

module mii_rx_tb;
    logic       rxclk = 0;
    logic [3:0] rxd   = 0;
    logic       rx_dv = 0;
    logic       rx_er = 0;
    logic       rst   = 0;
    logic [7:0] data;
    logic       valid;
    logic       frame_active;

    mii_rx dut(.rxclk, .rxd, .rx_dv, .rx_er, .rst, .data, .valid, .frame_active);

    always #20 rxclk = ~rxclk; //25MHz, 40ns period (5 times slower lol)

    task automatic sendbyte(input logic [7:0] testdata);
        @(negedge rxclk); #1;
        rxd = testdata[3:0]; //lower nibble needs to be stable before upcoming posedge
        @(negedge rxclk); #1;
        rxd = testdata[7:4]; //upper nibble
    endtask

    initial begin
        $dumpfile("mii_rx_tb.vcd");
        $dumpvars(0, mii_rx_tb);

        rx_dv = 0;
        rx_er = 0;
        rxd   = 0;

        rst = 1;
        repeat(16) @(posedge rxclk); //hold reset
        rst = 0;

        repeat(8) @(posedge rxclk); //idle wait before frame

        @(negedge rxclk); #1;
        rx_dv = 1; 

        repeat(7) sendbyte(8'h55); //preamble 
        sendbyte(8'hD5);           //SFD

        //test destination MAC addr
        sendbyte(8'hAA);
        sendbyte(8'hBB);
        sendbyte(8'hCC);
        sendbyte(8'hDD);
        sendbyte(8'hEE);
        sendbyte(8'hFF);

        @(posedge rxclk); //end frame with one extra pos edge to read last byte
        @(negedge rxclk); #1;
        rx_dv = 0;
        rxd   = 0;

        repeat(8) @(posedge rxclk);
        $finish;
    end

    always @(posedge rxclk) begin
        if(valid) $display("[%0t ns] data = 0x%02X", $time, data);
    end
endmodule