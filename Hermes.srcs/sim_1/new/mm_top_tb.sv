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
 
localparam RX_PERIOD = 40;
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
    .KEEPALIVE_CYCLES(32'd500),
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
 
function automatic logic [15:0] tcp_checksum(
    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [15:0] tcp_length,
    input logic [15:0] src_port,
    input logic [15:0] dst_port,
    input logic [31:0] seq_num,
    input logic [31:0] ack_num,
    input logic [7:0] data_offset,
    input logic [7:0] flags,
    input logic [15:0] window_size
);
    logic [31:0] sum;
    logic [16:0] fold1;
    logic [15:0] fold2;
    sum = 0;
    sum = sum + {16'h0, src_ip[31:16]};
    sum = sum + {16'h0, src_ip[15:0]};
    sum = sum + {16'h0, dst_ip[31:16]};
    sum = sum + {16'h0, dst_ip[15:0]};
    sum = sum + 32'h0006;
    sum = sum + {16'h0, tcp_length};
    sum = sum + {16'h0, src_port};
    sum = sum + {16'h0, dst_port};
    sum = sum + {16'h0, seq_num[31:16]};
    sum = sum + {16'h0, seq_num[15:0]};
    sum = sum + {16'h0, ack_num[31:16]};
    sum = sum + {16'h0, ack_num[15:0]};
    sum = sum + {16'h0, data_offset, flags};
    sum = sum + {16'h0, window_size};
    fold1 = {1'b0, sum[15:0]} + {1'b0, sum[31:16]};
    fold2 = fold1[15:0] + {15'h0, fold1[16]};
    tcp_checksum = ~fold2;
endfunction
 
task automatic send_nibble(input logic [3:0] nib);
    @(posedge rx_clk);
    rxd <= nib;
    rx_dv <= 1;
endtask
 
task automatic send_byte(input logic [7:0] b);
    send_nibble(b[3:0]);
    send_nibble(b[7:4]);
endtask
 
task automatic send_preamble;
    integer i;
    for (i = 0; i < 7; i++) send_byte(8'h55);
    send_byte(8'hD5);
endtask
 
task automatic send_eth_frame(input logic [47:0] dst_mac, input logic [47:0] src_mac, input logic [15:0] etype,
    input logic [7:0] payload [], input integer payload_len);
    send_preamble();
    for (int i = 0; i < 6; i++) send_byte(dst_mac[8*i +: 8]);
    for (int i = 0; i < 6; i++) send_byte(src_mac[8*i +: 8]);
    send_byte(etype[15:8]);
    send_byte(etype[7:0]);
    for (int i = 0; i < payload_len; i++) send_byte(payload[i]);
    send_byte(8'h00); send_byte(8'h00); send_byte(8'h00); send_byte(8'h00);
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
    ip_total_len = 20 + ip_payload_len;
    eth_payload = new[ip_total_len];
    eth_payload[0] = 8'h45; eth_payload[1] = 8'h00;
    eth_payload[2] = ip_total_len[15:8]; eth_payload[3] = ip_total_len[7:0];
    eth_payload[4] = 8'h00; eth_payload[5] = 8'h01;
    eth_payload[6] = 8'h00; eth_payload[7] = 8'h00;
    eth_payload[8] = 8'h40; eth_payload[9] = protocol;
    eth_payload[10] = 8'h00; eth_payload[11] = 8'h00;
    eth_payload[12] = src_ip[31:24]; eth_payload[13] = src_ip[23:16];
    eth_payload[14] = src_ip[15:8];  eth_payload[15] = src_ip[7:0];
    eth_payload[16] = dst_ip[31:24]; eth_payload[17] = dst_ip[23:16];
    eth_payload[18] = dst_ip[15:8];  eth_payload[19] = dst_ip[7:0];
    for (int i = 0; i < ip_payload_len; i++) eth_payload[20+i] = ip_payload[i];
    send_eth_frame(dst_mac, src_mac, 16'h0800, eth_payload, ip_total_len);
endtask
 
task automatic send_arp_request(input logic [47:0] src_mac, input logic [31:0] src_ip);
    logic [7:0] arp_payload [28];
    arp_payload[0]=8'h00; arp_payload[1]=8'h01; arp_payload[2]=8'h08; arp_payload[3]=8'h00;
    arp_payload[4]=8'h06; arp_payload[5]=8'h04; arp_payload[6]=8'h00; arp_payload[7]=8'h01;
    arp_payload[8]=src_mac[47:40]; arp_payload[9]=src_mac[39:32]; arp_payload[10]=src_mac[31:24];
    arp_payload[11]=src_mac[23:16]; arp_payload[12]=src_mac[15:8]; arp_payload[13]=src_mac[7:0];
    arp_payload[14]=src_ip[31:24]; arp_payload[15]=src_ip[23:16];
    arp_payload[16]=src_ip[15:8]; arp_payload[17]=src_ip[7:0];
    arp_payload[18]=0; arp_payload[19]=0; arp_payload[20]=0;
    arp_payload[21]=0; arp_payload[22]=0; arp_payload[23]=0;
    arp_payload[24]=8'hC0; arp_payload[25]=8'hA8; arp_payload[26]=8'h01; arp_payload[27]=8'h64;
    send_eth_frame(48'hFFFFFFFFFFFF, src_mac, 16'h0806, arp_payload, 28);
endtask
 
task automatic send_ping(
    input logic [47:0] src_mac, input logic [31:0] src_ip,
    input logic [15:0] identifier, input logic [15:0] seq
);
    logic [7:0] icmp [16];
    logic [7:0] ip_payload [];
    ip_payload = new[16];
    icmp[0]=8'h08; icmp[1]=8'h00; icmp[2]=8'h00; icmp[3]=8'h00;
    icmp[4]=identifier[15:8]; icmp[5]=identifier[7:0];
    icmp[6]=seq[15:8]; icmp[7]=seq[7:0];
    icmp[8]=8'hDE; icmp[9]=8'hAD; icmp[10]=8'hBE; icmp[11]=8'hEF;
    icmp[12]=8'hCA; icmp[13]=8'hFE; icmp[14]=8'hBA; icmp[15]=8'hBE;
    for (int i = 0; i < 16; i++) ip_payload[i] = icmp[i];
    send_ip_frame(48'h00183E03E41B, src_mac, src_ip, 32'hC0A80164, 8'h01, ip_payload, 16);
endtask
 
task automatic send_tcp_synack(
    input logic [47:0] src_mac, input logic [31:0] src_ip,
    input logic [31:0] seq_num, input logic [31:0] ack_num
);
    logic [15:0] csum;
    logic [7:0] tcp [20];
    logic [7:0] ip_payload [];
    ip_payload = new[20];
    csum = tcp_checksum(src_ip, 32'hC0A80164, 16'd20, 16'd10000, 16'd12345,
                        seq_num, ack_num, 8'h50, 8'h12, 16'hFFFF);
    tcp[0]=8'h27; tcp[1]=8'h10; tcp[2]=8'h30; tcp[3]=8'h39;
    tcp[4]=seq_num[31:24]; tcp[5]=seq_num[23:16];
    tcp[6]=seq_num[15:8];  tcp[7]=seq_num[7:0];
    tcp[8]=ack_num[31:24]; tcp[9]=ack_num[23:16];
    tcp[10]=ack_num[15:8]; tcp[11]=ack_num[7:0];
    tcp[12]=8'h50; tcp[13]=8'h12;
    tcp[14]=8'hFF; tcp[15]=8'hFF;
    tcp[16]=csum[15:8]; tcp[17]=csum[7:0];
    tcp[18]=8'h00; tcp[19]=8'h00;
    for (int i = 0; i < 20; i++) ip_payload[i] = tcp[i];
    send_ip_frame(48'h00183E03E41B, src_mac, src_ip, 32'hC0A80164, 8'h06, ip_payload, 20);
endtask
 
integer tx_frame_count = 0;
always @(posedge tx_clk) begin
    if (tx_en) begin
        @(negedge tx_en);
        tx_frame_count++;
        $display("t=%0t TX frame #%0d sent", $time, tx_frame_count);
    end
end
 
//watch for header_valid, syn, ack going high on rx_clk
always @(posedge rx_clk) begin
    if (dut.tcprx_header_valid)
        $display("t=%0t [RX] tcp_rx header_valid! syn=%b ack=%b csum_err=%b flags=%02X",
                 $time, dut.tcprx_rx_syn, dut.tcprx_rx_ack,
                 dut.tcprx_csum_error, dut.tcprx_flags);
    if (dut.tcprx_csum_error)
        $display("t=%0t [RX] tcp_rx csum_error!", $time);
end
 
//watch for packed sync reaching tx side
always @(posedge tx_clk) begin
    if (dut.tcprx_hv_tx)
        $display("t=%0t [TX] tcprx_hv_tx high! syn=%b ack=%b", $time, dut.tcprx_syn_tx, dut.tcprx_ack_tx);
    if (dut.sess_established)
        $display("t=%0t [TX] TCP ESTABLISHED!", $time);
end
 
initial begin
    $dumpfile("mm_top_tb.vcd");
    $dumpvars(0, mm_top_tb);
 
    repeat(10) @(posedge rx_clk);
    @(posedge rx_clk);
    rst <= 0;
    $display("t=%0t reset released", $time);
    repeat(20) @(posedge rx_clk);
 
    $display("t=%0t sending ARP request", $time);
    send_arp_request(48'hAABBCCDDEEFF, 32'hC0A80101);
    repeat(100) @(posedge tx_clk);
    $display("t=%0t ARP test done, led=%b", $time, led);
 
    $display("t=%0t sending ICMP ping", $time);
    send_ping(48'hAABBCCDDEEFF, 32'hC0A80101, 16'h0001, 16'h0001);
    repeat(200) @(posedge tx_clk);
    $display("t=%0t ICMP test done", $time);
 
    repeat(300) @(posedge tx_clk);
    $display("t=%0t sending TCP SYN-ACK", $time);
    send_tcp_synack(48'hAABBCCDDEEFF, 32'hC0A80101, 32'h12345678, 32'hDEADBEF0);
    repeat(500) @(posedge tx_clk);
    $display("t=%0t TCP test done, established=%b led=%b", $time, dut.sess_established, led);
 
    if (led[3] !== 1'b0)
        $display("WARN: book_valid unexpectedly high before market data");
    else
        $display("t=%0t book_valid correctly low", $time);
 
    repeat(50) @(posedge tx_clk);
    $display("t=%0t total TX frames sent: %0d", $time, tx_frame_count);
    $display("t=%0t simulation done", $time);
    $finish;
end
 
initial begin
    #10_000_000;
    $display("TIMEOUT");
    $finish;
end
 
endmodule
