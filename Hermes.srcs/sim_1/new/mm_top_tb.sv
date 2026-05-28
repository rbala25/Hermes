`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/28/2026 11:47:22 AM
// Design Name: 
// Module Name: mm_top_tb
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


module mm_top_tb;

localparam RX_PERIOD = 40; //25 MHz
localparam TX_PERIOD = 40;
 
logic rx_clk = 0;
logic tx_clk = 0;
logic rst = 1;
logic [3:0] rxd = 0;
logic rx_dv = 0;
logic [3:0] txd;
logic tx_en;
logic uart_tx;
logic [3:0] led;
 
always #(RX_PERIOD/2) rx_clk = ~rx_clk;
always #(TX_PERIOD/2) tx_clk = ~tx_clk;
 
mm_top #(
    .MY_MAC(48'h00183E03E41B),
    .MY_IP(32'hC0A80164),   
    .CME_IP(32'hC0A80101),
    .CME_PORT(16'd10000),
    .SRC_PORT(16'd12345),
    .ISN(32'hDEADBEEF),
    .SEC_ID(32'd1),
    .MDP_PORT(16'd14310),
    .HALF_SPREAD(64'd250000000),
    .MAX_POSITION(32'd10),
    .QUOTE_SIZE(32'd1),
    .MAX_ORDER_RATE(16'd100),
    .LOSS_LIMIT(64'd5000000000000),
    .VWAP_LEVELS(4'd5),
    .SKEW_PER_CONTRACT(64'd25000000),
    .REFRESH_TICKS(25'd2),
    .CLK_FREQ(32'd25000000),
    .OFI_DECAY_TICKS(32'd1000),
    .OFI_SCALE(64'd25000000),
    .OFI_THRESHOLD(32'd10),
    .RETRANSMIT_CYCLES(32'd250),
    .KEEPALIVE_CYCLES(32'd500), //short
    .HMAC_NEGOTIATE(256'd0),
    .HMAC_ESTABLISH(256'd0)
) dut (
    .rx_clk(rx_clk),
    .tx_clk(tx_clk),
    .rst(rst),
    .rxd(rxd),
    .rx_dv(rx_dv),
    .txd(txd),
    .tx_en(tx_en),
    .uart_tx(uart_tx),
    .led(led)
);

endmodule
