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
    parameter logic [31:0] IP = 32'hC0A80164
    )(
    input logic tx_clk,
    input logic rx_clk,
    input logic rst,
    output logic [3:0] txd,
    output logic tx_en,
    input logic [3:0] rxd,
    input logic rx_dv
    );
    
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
logic [31:0] rep_src_ip;
logic [31:0] rep_dst_ip;
logic [15:0] rep_identifier;
logic [15:0] rep_seq;
logic [15:0] rep_total_len;
logic [15:0] rep_ip_id;
logic [15:0] rep_icmp_checksum_rx;
//assume stable before TX fires since header arrives before payload

logic [15:0] icmp_checksum_tx;

always_ff @(posedge rx_clk) begin
    if (rst) begin
        rep_dst_mac <=0;
        rep_src_ip <=0;
        rep_dst_ip <=0;
        rep_identifier <=0;
        rep_seq <=0;
        rep_total_len <=0;
        rep_ip_id <=0;
        rep_icmp_checksum_rx <=0;
    end else if (icmp_header_valid && icmp_type==8'h08 && icmp_code==8'h00) begin
        rep_dst_mac <=eth_src_mac;
        rep_src_ip <=ip_dest;
        rep_dst_ip <=ip_src;
        rep_identifier <=icmp_identifier;
        rep_seq <=icmp_seq_num;
        rep_total_len <=ip_total_len;
        rep_ip_id <=ip_id;
        rep_icmp_checksum_rx <=icmp_checksum_rx;
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
        fifo_wr_snap_meta <=0;
        fifo_wr_snap_tx <=0;
    end else begin
        fifo_wr_snap_meta <=fifo_wr_ptr;
        fifo_wr_snap_tx <=fifo_wr_snap_meta;
    end
end

logic fifo_valid_tx;
logic fifo_ready_from_ictx;
assign fifo_valid_tx = (fifo_rd_ptr != fifo_wr_snap_tx);
 
always_ff @(posedge rx_clk) begin //write
    if (rst) fifo_wr_ptr <=0;
    else if (icmp_header_valid && icmp_type==8'h08 && icmp_code==8'h00) fifo_wr_ptr <=0;
    else if (icmp_payload_valid) begin
        fifo_mem[fifo_wr_ptr] <=icmp_payload_data;
        fifo_wr_ptr <=fifo_wr_ptr + 1'b1;
    end
end
 
always_ff @(posedge tx_clk) begin //read
    if (rst) fifo_rd_ptr <=0;
    else if (fifo_valid_tx && fifo_ready_from_ictx) fifo_rd_ptr <=fifo_rd_ptr + 1'b1;
end

    
endmodule
