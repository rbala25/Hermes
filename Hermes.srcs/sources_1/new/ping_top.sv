`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 03:26:03 PM
// Design Name: 
// Module Name: ping_top
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

module ping_top #(
    parameter logic [31:0] IP = 32'hC0A80164,
    parameter logic [47:0] MAC = 48'h00183E03E41B
    )(
    input logic clk_100, 
    input logic tx_clk,
    input logic rx_clk,
    input logic rstb,
    output logic [3:0] txd,
    output logic tx_en,
    input logic [3:0] rxd,
    input logic rx_dv,
    output logic eth_rstn,
    output logic eth_ref_clk,
    output logic [3:0] led,
    output logic eth_mdc,
    output logic eth_mdio
    );
    
logic locked;
clk_gen u_clk_gen (
    .clk_100(clk_100),
    .clk_25(eth_ref_clk),
    .locked(locked)
);

logic rst;
assign rst = rstb;

logic rx_clk_buf;
BUFG u_rx_clk_buf (.I(rx_clk), .O(rx_clk_buf));

logic [19:0] rst_cnt;
logic phy_rstn;

always_ff @(posedge clk_100) begin
    if (!locked) begin
        rst_cnt <= 0;
        phy_rstn <= 0;
    end else if (!phy_rstn) begin
        rst_cnt <= rst_cnt + 1;
        if (rst_cnt == 20'hFFFFF) phy_rstn <= 1;
    end
end

assign eth_rstn = phy_rstn;

logic [7:0] mii_rx_data; //mii_rx
logic mii_rx_valid;
logic mii_rx_frame_active; 

logic [47:0] eth_dest_mac; //eth_parser
logic [47:0] eth_src_mac;
logic [15:0] eth_ether_type;
logic eth_header_valid;
logic [7:0] eth_payload_data;
logic eth_payload_valid;
logic eth_frame_done;
logic eth_error;   

logic [3:0] ip_version; //ip_parser
logic [3:0] ip_ihl;
logic [7:0] ip_dscp;
logic [15:0] ip_total_len;
logic [15:0] ip_id;
logic [2:0] ip_flags;
logic [12:0] ip_frag_offset;
logic [7:0] ip_ttl;
logic [7:0] ip_protocol;
logic [15:0] ip_checksum;
logic [31:0] ip_src;
logic [31:0] ip_dest;
logic ip_header_valid;
logic ip_checksum_val;
logic ip_is_fragment;
logic [7:0] ip_payload_data;
logic ip_payload_valid;
logic ip_payload_done;
logic ip_error;  

logic [7:0] icmp_type; //icmp_parser
logic [7:0] icmp_code;
logic [15:0] icmp_checksum_rx;
logic [15:0] icmp_identifier;
logic [15:0] icmp_seq_num;
logic icmp_header_valid;
logic icmp_checksum_val;
logic [7:0] icmp_payload_data;
logic icmp_payload_valid;
logic icmp_payload_done;
logic icmp_error;  

logic [7:0] ictx_data; //icmp tx to ip tx
logic ictx_valid;
logic ictx_ready;

logic [7:0] iptx_data; //ip_tx to eth_tx
logic iptx_valid;
logic iptx_ready;
 
logic [7:0] ethtx_data; //eth_tx to mii_tx
logic ethtx_valid;
logic ethtx_ready;

logic icmp_tx_done; //tx start stop signals
logic ip_tx_done;
logic eth_tx_done;
logic icmp_tx_start;
logic ip_tx_start;
logic eth_tx_start;

logic [47:0] rep_dst_mac; //params for response
logic [31:0] rep_dst_ip;
logic [15:0] rep_identifier;
logic [15:0] rep_seq;
logic [15:0] rep_total_len;
logic [15:0] rep_ip_id;
logic [15:0] rep_icmp_checksum_rx;
//assume stable before TX fires since header arrives before payload

logic [47:0] arp_reply_dst_mac; //arp signals
logic arp_pending;
logic arp_start;
logic arp_done;
logic [7:0] arp_payload_data;
logic arp_payload_valid;
logic arp_payload_ready; 

logic tx_is_arp;
logic [47:0] mux_dst_mac;
logic [15:0] mux_ether_type;
logic [7:0] mux_payload_data;
logic mux_payload_valid;
logic mux_payload_ready; //eth_tx's payload_ready
 
assign mux_dst_mac = tx_is_arp ? arp_reply_dst_mac : rep_dst_mac; //high - arp path, low - icmp/ip
assign mux_ether_type = tx_is_arp ? 16'h0806 : 16'h0800;
assign mux_payload_data = tx_is_arp ? arp_payload_data : iptx_data;
assign mux_payload_valid = tx_is_arp ? arp_payload_valid : iptx_valid;
 
assign iptx_ready = tx_is_arp ? 1'b0 : mux_payload_ready;
assign arp_payload_ready = tx_is_arp ? mux_payload_ready : 1'b0;

logic [15:0] icmp_checksum_tx;

always_ff @(posedge rx_clk_buf) begin
    if (rst) begin
        rep_dst_mac <= 0;
        rep_dst_ip <= 0;
        rep_identifier <= 0;
        rep_seq <= 0;
        rep_total_len <= 0;
        rep_ip_id <= 0;
        rep_icmp_checksum_rx <= 0;
    end else if (icmp_header_valid && icmp_type==8'h08 && icmp_code==8'h00) begin
        rep_dst_mac <= eth_src_mac;
        rep_dst_ip <= ip_src;
        rep_identifier <= icmp_identifier;
        rep_seq <= icmp_seq_num;
        rep_total_len <= ip_total_len;
        rep_ip_id <= ip_id;
        rep_icmp_checksum_rx <= icmp_checksum_rx;
    end
end

localparam FIFO_DEPTH = 256;
localparam FIFO_AW = $clog2(FIFO_DEPTH);
logic [7:0] fifo_mem [0:FIFO_DEPTH-1];
logic [FIFO_AW-1:0] fifo_wr_ptr; //rx_clk 
logic [FIFO_AW-1:0] fifo_rd_ptr; //tx_clk

logic [FIFO_AW-1:0] fifo_wr_snap_meta, fifo_wr_snap_tx;
always_ff @(posedge tx_clk) begin //metastability across clk domains
    if (rst) begin
        fifo_wr_snap_meta <= 0;
        fifo_wr_snap_tx <= 0;
    end else begin
        fifo_wr_snap_meta <= fifo_wr_ptr;
        fifo_wr_snap_tx <= fifo_wr_snap_meta;
    end
end

logic fifo_valid_tx;
logic fifo_ready_from_ictx;
assign fifo_valid_tx = (fifo_rd_ptr != fifo_wr_snap_tx);

logic fifo_rst_wr; // rx_clk domain pulse
logic fifo_rst_meta, fifo_rst_tx, fifo_rst_tx_r; // tx_clk domain sync + edge detect

always_ff @(posedge rx_clk_buf) begin
    if (rst) fifo_rst_wr <= 0;
    else fifo_rst_wr <= (icmp_header_valid && icmp_type==8'h08 && icmp_code==8'h00);
end

always_ff @(posedge tx_clk) begin
    if (rst) begin
        fifo_rst_meta <= 0;
        fifo_rst_tx <= 0;
        fifo_rst_tx_r <= 0;
    end else begin
        fifo_rst_meta <= fifo_rst_wr;
        fifo_rst_tx <= fifo_rst_meta;
        fifo_rst_tx_r <= fifo_rst_tx;
    end
end

logic fifo_rd_rst; 
assign fifo_rd_rst = fifo_rst_tx && !fifo_rst_tx_r;
 
always_ff @(posedge rx_clk_buf) begin //write
    if (rst) fifo_wr_ptr <= 0;
    else if (icmp_header_valid && icmp_type==8'h08 && icmp_code==8'h00) fifo_wr_ptr <= 0;
    else if (icmp_payload_valid) begin
        fifo_mem[fifo_wr_ptr] <= icmp_payload_data;
        fifo_wr_ptr <= fifo_wr_ptr + 1'b1;
    end
end
 
always_ff @(posedge tx_clk) begin //read
    if (rst) fifo_rd_ptr <= 0;
    else if (fifo_rd_rst) fifo_rd_ptr <= 0; //new packet: reset read pointer
    else if (fifo_valid_tx && fifo_ready_from_ictx) fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
end

typedef enum logic [1:0] { 
    idle, tx_wait 
} state_t;
state_t state;
 
always_ff @(posedge tx_clk) begin
    if (rst) begin
        state <= idle;
        icmp_tx_start <= 0;
        ip_tx_start <= 0;
        eth_tx_start <= 0;
        arp_start <= 0;
        tx_is_arp <= 0;
    end else begin
        icmp_tx_start <= 0;
        arp_start <= 0;
        ip_tx_start <= 0;
        eth_tx_start <= 0;
 
        unique case (state)
    idle: begin
        if (arp_pending) begin
            arp_start <= 1;
            eth_tx_start <= 1;
            tx_is_arp <= 1;
            state <= tx_wait;
        end else if (fifo_valid_tx) begin
            icmp_tx_start <= 1;
            ip_tx_start <= 1;
            eth_tx_start <= 1;
            tx_is_arp <= 0;
            state <= tx_wait;
        end
    end
 
            tx_wait: begin 
                if (eth_tx_done) state <= idle;
//                $display("TOP: eth_tx_done at t=%0t", $time);
            end
        endcase
    end
end

mii_rx u_mii_rx (
    .data(mii_rx_data),
    .valid(mii_rx_valid),
    .frame_active(mii_rx_frame_active),
    .rxclk(rx_clk_buf),
    .rxd(rxd),
    .rx_dv(rx_dv),
    .rx_er(1'b0),
    .rst(rst)
);
 
eth_parser u_eth_parser (
    .dest_mac(eth_dest_mac),
    .src_mac(eth_src_mac),
    .ether_type(eth_ether_type),
    .header_valid(eth_header_valid),
    .payload_data(eth_payload_data),
    .payload_valid(eth_payload_valid),
    .frame_done(eth_frame_done),
    .error(eth_error),
    .clk(rx_clk_buf),
    .rst(rst),
    .data(mii_rx_data),
    .valid(mii_rx_valid),
    .frame_active(mii_rx_frame_active)
);
 
ip_parser u_ip_parser (
    .clk(rx_clk_buf),
    .rst(rst),
    .payload(eth_payload_data),
    .payload_valid(eth_payload_valid),
    .header_valid(eth_header_valid),
    .ether(eth_ether_type),
    .frame_done(eth_frame_done),
    .error(eth_error),
    .ip_version(ip_version),
    .ip_ihl(ip_ihl),
    .ip_dscp(ip_dscp),
    .ip_total_len(ip_total_len),
    .ip_id(ip_id),
    .ip_flags(ip_flags),
    .ip_frag_offset(ip_frag_offset),
    .ip_ttl(ip_ttl),
    .ip_protocol(ip_protocol),
    .ip_checksum(ip_checksum),
    .ip_src(ip_src),
    .ip_dest(ip_dest),
    .ip_header_valid(ip_header_valid),
    .ip_checksum_val(ip_checksum_val),
    .ip_is_fragment(ip_is_fragment),
    .ip_payload_data(ip_payload_data),
    .ip_payload_valid(ip_payload_valid),
    .ip_payload_done(ip_payload_done),
    .ip_error(ip_error)
);
 
icmp_parser u_icmp_parser (
    .clk(rx_clk_buf),
    .rst(rst),
    .payload(ip_payload_data),
    .payload_valid(ip_payload_valid),
    .ip_header_valid(ip_header_valid),
    .ip_payload_done(ip_payload_done),
    .ip_protocol(ip_protocol),
    .error(ip_error),
    .icmp_type(icmp_type),
    .icmp_code(icmp_code),
    .icmp_checksum(icmp_checksum_rx),
    .icmp_identifier(icmp_identifier),
    .icmp_seq_num(icmp_seq_num),
    .icmp_header_valid(icmp_header_valid),
    .icmp_checksum_val(icmp_checksum_val),
    .icmp_payload_data(icmp_payload_data),
    .icmp_payload_valid(icmp_payload_valid),
    .icmp_payload_done(icmp_payload_done),
    .icmp_error(icmp_error)
);
 
icmp_csum_adjust u_csum_adjust (
    .csum_in(rep_icmp_checksum_rx),
    .csum_out(icmp_checksum_tx)
);
 
icmp_tx u_icmp_tx (
    .tx_clk(tx_clk),
    .rst(rst),
    .identifier(rep_identifier),
    .seq(rep_seq),
    .icmp_checksum(icmp_checksum_tx),
    .start(icmp_tx_start),
    .done(icmp_tx_done),
    .payload_in_data(fifo_mem[fifo_rd_ptr]),
    .payload_in_valid(fifo_valid_tx),
    .payload_in_ready(fifo_ready_from_ictx),
    .payload_data(ictx_data),
    .payload_valid(ictx_valid),
    .payload_ready(ictx_ready)
);
 
ip_tx u_ip_tx (
    .tx_clk(tx_clk),
    .rst(rst),
    .src_ip(IP),
    .dst_ip(rep_dst_ip),
    .protocol(8'h01),
    .total_length(rep_total_len),
    .identification(rep_ip_id),
    .start(ip_tx_start),
    .done(ip_tx_done),
    .payload_data(ictx_data),
    .payload_valid(ictx_valid),
    .payload_ready(ictx_ready),
    .tx_data(iptx_data),
    .tx_valid(iptx_valid),
    .tx_ready(iptx_ready)
);
 
eth_tx u_eth_tx (
    .tx_clk(tx_clk),
    .rst(rst),
    .dst_mac(mux_dst_mac), //mux
    .ether_type(mux_ether_type), //mux
    .payload_data(mux_payload_data),
    .payload_valid(mux_payload_valid),
    .start(eth_tx_start),
    .payload_ready(mux_payload_ready),
    .done(eth_tx_done),
    .txd(ethtx_data),
    .tx_valid(ethtx_valid),
    .tx_ready(ethtx_ready)
);
 
mii_tx u_mii_tx (
    .tx_clk(tx_clk),
    .rst(rst),
    .data(ethtx_data),
    .valid(ethtx_valid),
    .ready(ethtx_ready),
    .txd(txd),
    .tx_en(tx_en)
);

arp_handler #(
    .MY_IP(IP),
    .MY_MAC(MAC)
) u_arp_handler (
    .rx_clk(rx_clk_buf),
    .tx_clk(tx_clk),
    .rst(rst),
    .eth_ether_type(eth_ether_type),
    .eth_header_valid(eth_header_valid),
    .eth_payload_data(eth_payload_data),
    .eth_payload_valid(eth_payload_valid),
    .eth_frame_done(eth_frame_done),
    .eth_error(eth_error),
    .reply_dst_mac(arp_reply_dst_mac),
    .pending(arp_pending),
    .start(arp_start),
    .done(arp_done),
    .payload_data(arp_payload_data),
    .payload_valid(arp_payload_valid),
    .payload_ready(arp_payload_ready)
);

logic mdio_done;

mdio_init u_mdio_init (
    .clk(clk_100),
    .rst(!phy_rstn),
    .mdc(eth_mdc),
    .mdio(eth_mdio),
    .done(mdio_done)
);

//assign led[0] = arp_pending;
//assign led[1] = eth_header_valid;

//logic eth_hv_seen;
//always_ff @(posedge rx_clk_buf) begin  // rx_clk_buf, not rx_clk
//    if (rst) eth_hv_seen <= 0;
//    else if (eth_header_valid) eth_hv_seen <= 1;
//end
//assign led[0] = eth_hv_seen;

//logic arp_etype_seen;
//always_ff @(posedge rx_clk_buf) begin
//    if (rst) arp_etype_seen <= 0;
//    else if (eth_header_valid && eth_ether_type == 16'h0806) arp_etype_seen <= 1;
//end
//assign led[0] = arp_etype_seen;

logic arp_pending_seen;
always_ff @(posedge tx_clk) begin
    if (rst) arp_pending_seen <= 0;
    else if (arp_pending) arp_pending_seen <= 1;
end
//assign led[0] = arp_pending_seen;

//logic mii_rx_seen;
//always_ff @(posedge rx_clk_buf) begin
//    if (rst) mii_rx_seen <= 0;
//    else if (mii_rx_valid) mii_rx_seen <= 1;
//end

////assign led[1] = mii_rx_seen;
//assign led[1] = mdio_done;

//assign led[2] = locked;
////assign led[3] = tx_is_arp; 
logic rx_dv_seen;

always_ff @(posedge rx_clk_buf) begin
    if (rst) rx_dv_seen <= 0;
    else if (rx_dv) rx_dv_seen <= 1;
end

//assign led[3] = rx_dv_seen;

//logic rx_clk_r;
//logic rx_clk_seen;
//always_ff @(posedge clk_100) begin
//    rx_clk_r <= rx_clk;
//    if (!phy_rstn) rx_clk_seen <= 0;
//    else if (rx_clk & ~rx_clk_r) rx_clk_seen <= 1;
//end
//assign led[3] = rx_clk_seen;

assign led[0] = mdio_done;//PHY init complete
assign led[1] = locked; //PLL locked
assign led[2] = rx_dv_seen; //Any RX traffic seen (from PC)
assign led[3] = arp_pending_seen; //ARP request received and queued 
endmodule
