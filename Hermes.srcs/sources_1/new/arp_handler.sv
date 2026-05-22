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
 
                        5'd8: sender_mac_rx[47:40] <= eth_payload_data; //sender mac address
                        5'd9: sender_mac_rx[39:32] <= eth_payload_data;
                        5'd10: sender_mac_rx[31:24] <= eth_payload_data;
                        5'd11: sender_mac_rx[23:16] <= eth_payload_data;
                        5'd12: sender_mac_rx[15:8] <= eth_payload_data;
                        5'd13: sender_mac_rx[7:0] <= eth_payload_data;
 
                        5'd14: sender_ip_rx[31:24] <= eth_payload_data; //sender ip addr
                        5'd15: sender_ip_rx[23:16] <= eth_payload_data;
                        5'd16: sender_ip_rx[15:8] <= eth_payload_data;
                        5'd17: sender_ip_rx[7:0] <= eth_payload_data;
 
                        5'd18, 5'd19, 5'd20, 5'd21, 5'd22, 5'd23: ; //THA (all zeroes bc request doesnt know MAC yet)
 
                        5'd24: tpa_build[31:24] <= eth_payload_data; //TPA, need to check against ours
                        5'd25: tpa_build[23:16] <= eth_payload_data;
                        5'd26: tpa_build[15:8] <= eth_payload_data;
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

//arp_toggle cdc sync
logic toggle_meta, toggle_sync, toggle_prev;
logic [47:0] sender_mac_cdc;
logic [31:0] sender_ip_cdc;
 
always_ff @(posedge tx_clk) begin
    if (rst) begin
        toggle_meta <= 0;
        toggle_sync <= 0;
        toggle_prev <= 0;
        reply_dst_mac <= 0;
        sender_mac_cdc <= 0;
        sender_ip_cdc <= 0;
    end else begin
        toggle_meta <= arp_toggle_rx;
        toggle_sync <= toggle_meta;
        toggle_prev <= toggle_sync;
 
        if (toggle_sync != toggle_prev) begin
            reply_dst_mac <= sender_mac_rx; //sha
            sender_mac_cdc <= sender_mac_rx;
            sender_ip_cdc <= sender_ip_rx;
        end
    end
end

logic req_edge;
assign req_edge = (toggle_sync != toggle_prev); //xor

//tx
typedef enum logic [1:0] {
    TX_IDLE,
    TX_SEND
} tx_state_t;
 
tx_state_t tx_state;
logic [4:0] tx_cnt;
 
always_ff @(posedge tx_clk) begin
    if (rst) begin
        tx_state <= TX_IDLE;
        tx_cnt <= 0;
        pending <= 0;
        done <= 0;
        payload_data <= 0;
        payload_valid <= 0;
    end else begin
        done <= 0;
 
        if (start) pending <= 0;
        else if (req_edge) pending <= 1; //wait for pending
 
        unique case (tx_state)
            TX_IDLE: begin
                payload_valid <= 0;
                tx_cnt <= 0;
                if (start) begin
                    payload_data <= 8'h00; //byte 1 (htype high 0x00)
                    payload_valid <= 1;
                    tx_cnt <= 1;
                    tx_state <= TX_SEND;
                end
            end
 
            TX_SEND: begin
                if (payload_ready) begin
                    tx_cnt <= tx_cnt + 1;
                    case (tx_cnt)
                        5'd1: payload_data <= 8'h01;     
                        5'd2: payload_data <= 8'h08; //ether ipv4
                        5'd3: payload_data <= 8'h00; 
                        5'd4: payload_data <= 8'h06; //hlen
                        5'd5: payload_data <= 8'h04; //plen  
                        5'd6: payload_data <= 8'h00; 
                        5'd7: payload_data <= 8'h02; //oper low reply 0x0002

                        5'd8: payload_data <= MY_MAC[47:40]; //sha
                        5'd9: payload_data <= MY_MAC[39:32];
                        5'd10: payload_data <= MY_MAC[31:24];
                        5'd11: payload_data <= MY_MAC[23:16];
                        5'd12: payload_data <= MY_MAC[15:8];
                        5'd13: payload_data <= MY_MAC[7:0];
                        
                        5'd14: payload_data <= MY_IP[31:24]; //spa
                        5'd15: payload_data <= MY_IP[23:16];
                        5'd16: payload_data <= MY_IP[15:8];
                        5'd17: payload_data <= MY_IP[7:0];
     
                        5'd18: payload_data <= sender_mac_cdc[47:40]; //tha
                        5'd19: payload_data <= sender_mac_cdc[39:32];
                        5'd20: payload_data <= sender_mac_cdc[31:24];
                        5'd21: payload_data <= sender_mac_cdc[23:16];
                        5'd22: payload_data <= sender_mac_cdc[15:8];
                        5'd23: payload_data <= sender_mac_cdc[7:0];

                        5'd24: payload_data <= sender_ip_cdc[31:24]; //tpa
                        5'd25: payload_data <= sender_ip_cdc[23:16];
                        5'd26: payload_data <= sender_ip_cdc[15:8];
                        5'd27: payload_data <= sender_ip_cdc[7:0]; 
                        5'd28: begin
                            payload_valid <= 0;
                            done <= 1;
                            tx_state <= TX_IDLE;
                        end
                        default: ;
                    endcase
                end
            end
        endcase
    end
end

endmodule
