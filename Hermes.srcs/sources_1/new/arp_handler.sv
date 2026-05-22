`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/22/2026 05:25:16 PM
// Design Name: 
// Module Name: arp_handler
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


module arp_handler #(
    parameter logic [31:0] MY_IP = 32'hC0A80164,
    parameter logic [47:0] MY_MAC = 48'h00183E03E41B
)(
    input logic rx_clk,
    input logic tx_clk,
    input logic rst,
    
    input logic [15:0] eth_ether_type, //from eth_parser
    input logic eth_header_valid,
    input logic [7:0] eth_payload_data,
    input logic eth_payload_valid,
    input logic eth_frame_done,
    input logic eth_error,
 
    //this is for tx side
    output logic [47:0] reply_dst_mac, //dst_mac to give eth_tx for the reply
    output logic pending, //1 = reply waiting to be sent
    input logic start,
    output logic done,
    output logic [7:0] payload_data, //28-byte ARP payload
    output logic payload_valid,
    input logic payload_ready
);


endmodule
