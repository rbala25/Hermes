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
 
    output logic [47:0] reply_dst_mac, //dst_mac to give eth_tx for the reply
    output logic pending, //need permission from ping top (shared eth tx bus)
    input logic start,
    output logic done,
    output logic [7:0] payload_data, //28-byte ARP payload
    output logic payload_valid,
    input logic payload_ready
);

//rx side
typedef enum logic [1:0] {
    RX_SKIP,
    RX_PARSE
} rx_state_t;
 
rx_state_t rx_state;
logic [4:0] rx_cnt;
logic [7:0] rx_prev; //buf
logic rx_ok;
 
logic [47:0] sender_mac_rx;
logic [31:0] sender_ip_rx;
logic [31:0] tpa_build;
 
logic arp_toggle_rx; //transition is signal to tx (toggle safer than pulse)

always_ff @(posedge rx_clk) begin
    if (rst) begin
        rx_state <= RX_SKIP;
        rx_cnt <= 0;
        rx_prev <= 0;
        rx_ok <= 1;
        sender_mac_rx <= 0;
        sender_ip_rx <= 0;
        tpa_build <= 0;
        arp_toggle_rx <= 0;
    end else begin
        if (eth_error || eth_frame_done) begin
            rx_state <= RX_SKIP;
            rx_cnt <= 0;
        end else if (eth_header_valid) begin
            rx_cnt <= 0;
            rx_ok <= 1;
            rx_state <= (eth_ether_type == 16'h0806) ? RX_PARSE : RX_SKIP;
        end else if (eth_payload_valid) begin
            unique case (rx_state)
                RX_SKIP: ;
 
                RX_PARSE: begin
                    rx_cnt <= rx_cnt + 1;
                    rx_prev <= eth_payload_data;
 
                    case (rx_cnt)
                        5'd0: ; //htype 2 bytes (0x0001 is ethernet)
                        5'd1: if ({rx_prev, eth_payload_data} != 16'h0001) rx_ok <= 0;
 
                        5'd2: ; //ptype
                        5'd3: if ({rx_prev, eth_payload_data} != 16'h0800) rx_ok <= 0;
 
                        5'd4: if (eth_payload_data != 8'h06) rx_ok <= 0; //hlen must be 6 (MAC is 6 bytes)
 
                        5'd5: if (eth_payload_data != 8'h04) rx_ok <= 0; //plen (0x04 = 4 bytes for IPv4 addr)
 
                        5'd6: ;
                        5'd7: if ({rx_prev, eth_payload_data} != 16'h0001) rx_ok <= 0; //operation (1 = request, 2 = reply)
 
                        5'd8:  sender_mac_rx[47:40] <= eth_payload_data; //sender mac address
                        5'd9:  sender_mac_rx[39:32] <= eth_payload_data;
                        5'd10: sender_mac_rx[31:24] <= eth_payload_data;
                        5'd11: sender_mac_rx[23:16] <= eth_payload_data;
                        5'd12: sender_mac_rx[15:8]  <= eth_payload_data;
                        5'd13: sender_mac_rx[7:0]   <= eth_payload_data;
 
                        5'd14: sender_ip_rx[31:24] <= eth_payload_data; //sender ip addr
                        5'd15: sender_ip_rx[23:16] <= eth_payload_data;
                        5'd16: sender_ip_rx[15:8]  <= eth_payload_data;
                        5'd17: sender_ip_rx[7:0]   <= eth_payload_data;
 
                        5'd18, 5'd19, 5'd20, 5'd21, 5'd22, 5'd23: ; //THA (all zeroes bc request doesnt know MAC yet)
 
                        5'd24: tpa_build[31:24] <= eth_payload_data; //TPA, need to check against ours
                        5'd25: tpa_build[23:16] <= eth_payload_data;
                        5'd26: tpa_build[15:8]  <= eth_payload_data;
                        5'd27: begin
                            if (rx_ok && {tpa_build[31:8], eth_payload_data} == MY_IP) //save 1 cycle
                                arp_toggle_rx <= ~arp_toggle_rx;
                            rx_state <= RX_SKIP;
                        end
 
                        default: rx_state <= RX_SKIP;
                    endcase
                end
            endcase
        end
    end
end


endmodule
