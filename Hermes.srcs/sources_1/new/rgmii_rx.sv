`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: rgmii_rx
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


module rgmii_rx(output logic [7:0] data, output logic valid, output logic frame_active, 
                input logic rxclk, input logic[3:0] rxd, input logic rx_ctl);
                
//need to capture on both edges - use IDDR
logic [3:0] rxd_rise, rxd_fall;
logic ctlrise, ctlfall;

genvar i;
generate
    for(i=0; i<4; i++) begin : ddr_data
        IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .INIT_Q1(0), .INIT_Q2(0))
        iddr_rx (.C(rxclk), .CE(1), .D(rxd[i]), .Q1(rxd_rise[i]), .Q2(rxd_fall[i]), .R(0), .S(0));
    end
endgenerate;

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .INIT_Q1(0), .INIT_Q2(0))
iddr_ctl (.C(rxc), .CE(1'b1), .D(rx_ctl), .Q1(ctl_rise), .Q2(ctl_fall), .R(0), .S(0)); //rx_ctl is also DDR
//rx_dv rising edge - high when data valid
//rx_er falling edge - XOR with rx_dv -> if high, error

logic [7:0] rawdata;
logic rawvalid;
//cant put it directly bc we have to make sure valid and no errors


endmodule
