`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/22/2026 03:52:33 PM
// Design Name: 
// Module Name: clk_gen
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


module clk_gen( input logic clk_100, output logic clk_25, output logic locked );

wire clkfb;
wire clk_25_unbuf;

MMCME2_BASE #(
    .CLKIN1_PERIOD(10.0),   //100 MHz
    .CLKFBOUT_MULT_F(10.0), //100 * 10
    .CLKOUT0_DIVIDE_F(40.0), //1000/40 = 25 MHz
    .DIVCLK_DIVIDE(1)
) mmcm (
    .CLKIN1(clk_100),
    .CLKFBIN(clkfb),
    .CLKFBOUT(clkfb),
    .CLKOUT0(clk_25_unbuf),
    .LOCKED(locked),
    .PWRDWN(1'b0),
    .RST(1'b0)
);

BUFG buf_25 (.I(clk_25_unbuf), .O(clk_25));

endmodule
