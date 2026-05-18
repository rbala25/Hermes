`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:47:23 PM
// Design Name: 
// Module Name: rgmii_rx_tb
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


module rgmii_rx_tb;
    logic rxclk = 0;
    logic [3:0] rxd = 0;
    logic rx_ctl = 0;
    logic [7:0] data;
    logic valid;
    logic frame_active;
    
    rgmii_rx dut(.rxclk, .rxd, .rx_ctl, .data, .valid, .frame_active);
    
    always #4 rxclk = ~rxclk;
    
    task sendbyte (input logic [7:0] testdata);
        @(negedge rxclk);
        data = testdata[7:4];
        rx_ctl = 1'b1;
        
        @(negedge rxclk);
        data = testdata[3:0];
        rx_ctl = 1'b1;
    endtask

endmodule
