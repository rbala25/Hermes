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

task automatic send_nibble(input logic [3:0] nib);
    @(posedge rx_clk);
    rxd <= nib;
    rx_dv <= 1;
endtask

task automatic send_byte(input logic [7:0] b);
    send_nibble(b[3:0]);
    send_nibble(b[7:4]);
endtask
 
task automatic send_preamble; //7 preamble + sfd
    integer i;
    for (i = 0; i < 7; i++) send_byte(8'h55);
    send_byte(8'hD5);
endtask

task automatic send_eth_frame(input logic [47:0] dst_mac, input logic [47:0] src_mac, input logic [15:0] etype,
    input logic [7:0] payload [], input integer payload_len);
    send_preamble();
    for (int i = 0; i < 6; i++) send_byte(dst_mac[8*i +: 8]); //dst mac
    for (int i = 0; i < 6; i++) send_byte(src_mac[8*i +: 8]);
    send_byte(etype[15:8]);
    send_byte(etype[7:0]);
    for (int i = 0; i < payload_len; i++) send_byte(payload[i]);
    @(posedge rx_clk);
    rx_dv <= 0;
    rxd <= 0;
    repeat(24) @(posedge rx_clk);
endtask

task automatic send_ip_frame(
    input logic [47:0] dst_mac,
    input logic [47:0] src_mac,
    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [7:0] protocol,
    input logic [7:0] ip_payload [],
    input integer ip_payload_len
);
    logic [7:0] eth_payload [];
    integer ip_total_len;
    integer i;
 
    ip_total_len = 20 + ip_payload_len; //20 byte header
    eth_payload = new[ip_total_len];
 
    eth_payload[0] = 8'h45;
    eth_payload[1] = 8'h00;
    eth_payload[2] = ip_total_len[15:8];
    eth_payload[3] = ip_total_len[7:0];
    eth_payload[4] = 8'h00; 
    eth_payload[5] = 8'h01;
    eth_payload[6] = 8'h00; 
    eth_payload[7] = 8'h00;
    eth_payload[8] = 8'h40; 
    eth_payload[9] = protocol;
    eth_payload[10] = 8'h00; //csum ignore
    eth_payload[11] = 8'h00; 
    eth_payload[12] = src_ip[31:24];
    eth_payload[13] = src_ip[23:16];
    eth_payload[14] = src_ip[15:8];
    eth_payload[15] = src_ip[7:0];
    eth_payload[16] = dst_ip[31:24];
    eth_payload[17] = dst_ip[23:16];
    eth_payload[18] = dst_ip[15:8];
    eth_payload[19] = dst_ip[7:0];
 
    for (i = 0; i < ip_payload_len; i++)
        eth_payload[20 + i] = ip_payload[i];
 
    send_eth_frame(dst_mac, src_mac, 16'h0800, eth_payload, ip_total_len);
endtask

task automatic send_arp_request(
    input logic [47:0] src_mac,
    input logic [31:0] src_ip
);
    logic [7:0] arp_payload [28];
    arp_payload[0] = 8'h00;
    arp_payload[1] = 8'h01; 
    arp_payload[2] = 8'h08;
    arp_payload[3] = 8'h00;
    arp_payload[4] = 8'h06;  
    arp_payload[5] = 8'h04;   
    arp_payload[6] = 8'h00; arp_payload[7] = 8'h01;
    
    arp_payload[8]  = src_mac[47:40];
    arp_payload[9]  = src_mac[39:32];
    arp_payload[10] = src_mac[31:24];
    arp_payload[11] = src_mac[23:16];
    arp_payload[12] = src_mac[15:8];
    arp_payload[13] = src_mac[7:0];

    arp_payload[14] = src_ip[31:24];
    arp_payload[15] = src_ip[23:16];
    arp_payload[16] = src_ip[15:8];
    arp_payload[17] = src_ip[7:0];

    arp_payload[18] = 0; //unknown dest mac
    arp_payload[19] = 0; 
    arp_payload[20] = 0;
    arp_payload[21] = 0; 
    arp_payload[22] = 0; 
    arp_payload[23] = 0;

    arp_payload[24] = 8'hC0; 
    arp_payload[25] = 8'hA8; 
    arp_payload[26] = 8'h01;
    arp_payload[27] = 8'h64; 
    send_eth_frame(48'hFFFFFFFFFFFF, src_mac, 16'h0806, arp_payload, 28);
endtask

endmodule
