`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 07:47:41 PM
// Design Name: 
// Module Name: tcp_session
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


module tcp_session #(
    parameter CLK_FREQ = 25_000_000, 
    parameter RETRANSMIT_CYCLES = CLK_FREQ, //1 second retransmit timeout
    parameter KEEPALIVE_CYCLES = CLK_FREQ //1 second keepalive interval
)(
    input logic clk,
    input logic rst,
 
    input logic connect, 
    input logic disconnect, //pulse
 
    input logic [15:0] src_port,
    input logic [15:0] dst_port,
    input logic [15:0] window_size,
    input logic [31:0] isn,
 
    input logic rx_syn,//tcp rx
    input logic rx_ack,
    input logic rx_fin,
    input logic rx_rst,
    input logic [31:0] rx_seq_num, 
    input logic header_valid, 
 

    output logic ctrl_start, //tcp tx
    output logic [7:0] ctrl_flags,
    output logic [31:0] ctrl_ack_num,
    output logic [15:0] ctrl_tcp_length, 
    output logic [15:0] ctrl_payload_csum,
    input logic tx_done,
 
    output logic load_seq,//pulse
    output logic [31:0] init_seq,
 
    output logic tx_grant, //high when established and tcp_tx is free
 
    output logic established,
    output logic closed
);

typedef enum logic [2:0] {
    S_CLOSED,
    S_SYN_SENT,
    S_ESTABLISHED,
    S_FIN_WAIT_1,
    S_FIN_WAIT_2,
    S_TIME_WAIT
} state_t;
 
state_t state;
 
logic [31:0] retransmit_cnt;
logic [31:0] keepalive_cnt;
logic [31:0] ack_num_r; //ack num
logic tx_busy; //tcp_tx is mid-segment

always_ff @(posedge clk) begin
    if (rst) begin
        state <= S_CLOSED;
        ctrl_start <= 0;
        ctrl_flags <= 0;
        ctrl_ack_num <= 0;
        ctrl_tcp_length <= 16'd20;
        ctrl_payload_csum <= 0;
        load_seq <= 0;
        init_seq <= 0;
        ack_num_r <= 0;
        retransmit_cnt <= 0;
        keepalive_cnt <= 0;
        tx_busy <= 0;
        established <= 0;
        closed <= 1;
        tx_grant <= 0;
    end else begin
        ctrl_start <= 0;
        load_seq <= 0;

        if (ctrl_start) tx_busy <= 1;
        if (tx_done) tx_busy <= 0;
 
        if (header_valid) begin
//            if (rx_syn || rx_fin)
//                ack_num_r <= rx_seq_num + 32'd1;
//            else
//                ack_num_r <= rx_seq_num + 32'd1; 
              ack_num_r <= rx_seq_num + 32'd1; 
        end
 
        if (rx_rst) begin
            state <= S_CLOSED;
            established <= 0;
            closed <= 1;
            tx_grant <= 0;
            tx_busy <= 0;
            keepalive_cnt <= 0;
            retransmit_cnt <= 0;
        end else begin
            unique case (state)
                S_CLOSED: begin
                    established <= 0;
                    closed <= 1;
                    tx_grant <= 0;
                    if (connect) begin
                        init_seq <= isn;
                        load_seq <= 1;
                        ctrl_flags <= 8'h02; //SYN
                        ctrl_ack_num <= 0;
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        retransmit_cnt <= 0;
                        state <= S_SYN_SENT;
                    end
                end
 
                S_SYN_SENT: begin
                    established <= 0;
                    closed <= 0;
                    tx_grant <= 0;
                    retransmit_cnt <= retransmit_cnt + 1;
                    if (header_valid && rx_syn && rx_ack) begin //received SYN-ACK
                        ctrl_flags <= 8'h10; //ACK
                        ctrl_ack_num <= rx_seq_num + 32'd1; //direct
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        retransmit_cnt <= 0;
                        keepalive_cnt <= 0;
                        state <= S_ESTABLISHED;
                    end else if (retransmit_cnt >= RETRANSMIT_CYCLES && !tx_busy) begin //retransmit
                        init_seq <= isn;
                        load_seq <= 1;
                        ctrl_flags <= 8'h02;
                        ctrl_ack_num <= 0;
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        retransmit_cnt <= 0;
                    end
                end
 
                S_ESTABLISHED: begin
                    established <= 1;
                    closed <= 0;
                    tx_grant <= !tx_busy;
                    keepalive_cnt <= keepalive_cnt + 1;
                    if (disconnect) begin
                        tx_grant <= 0;
                        ctrl_flags <= 8'h11; //fin and ack
                        ctrl_ack_num <= ack_num_r;
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        keepalive_cnt <= 0;
                        state <= S_FIN_WAIT_1;
                    end else if (header_valid && rx_fin) begin
                        tx_grant <= 0;
                        ctrl_flags <= 8'h11; //ack fin and return
                        ctrl_ack_num <= ack_num_r;
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        keepalive_cnt <= 0;
                        state <= S_FIN_WAIT_1;
                    end else if (keepalive_cnt >= KEEPALIVE_CYCLES && !tx_busy) begin
                        ctrl_flags <= 8'h10; 
                        ctrl_ack_num <= ack_num_r;
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        keepalive_cnt <= 0;
                    end
                end
 
                S_FIN_WAIT_1: begin
                    established <= 0;
                    closed <= 0;
                    tx_grant <= 0;
                    if (header_valid && rx_ack) begin
                        state <= S_FIN_WAIT_2;
                    end
                end
 
                S_FIN_WAIT_2: begin //ignoring any data after they ack our fin
                    established <= 0;
                    closed <= 0;
                    tx_grant <= 0;
                    if (header_valid && rx_fin) begin //send final ack
                        ctrl_flags <= 8'h10; //ack
                        ctrl_ack_num <= ack_num_r;
                        ctrl_tcp_length <= 16'd20;
                        ctrl_payload_csum <= 0;
                        ctrl_start <= 1;
                        retransmit_cnt <= 0;
                        state <= S_TIME_WAIT;
                    end
                end
 
                S_TIME_WAIT: begin
                    established <= 0;
                    closed <= 0;
                    tx_grant <= 0;
                    retransmit_cnt <= retransmit_cnt + 1;
                    if (retransmit_cnt >= 2 * RETRANSMIT_CYCLES) begin
                        retransmit_cnt <= 0;
                        state <= S_CLOSED;
                    end
                end
            endcase
        end
    end
end

endmodule
