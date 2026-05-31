`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 04:32:06 PM
// Design Name: 
// Module Name: tcp_rx
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



module tcp_rx(
    input logic rx_clk,
    input logic rst,
 
    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [15:0] tcp_length,
 
    input logic [7:0] data_in, //incoming bytes
    input logic data_in_valid,
    input logic data_in_last, //one cycle pulse on final byte of TCP segment
    output logic data_in_ready,
 
    output logic [15:0] src_port, //parsed header fields
    output logic [15:0] dst_port,
    output logic [31:0] seq_num,
    output logic [31:0] ack_num,
    output logic [7:0] flags,
    output logic [15:0] window_size,
    output logic header_valid, //single cycle pulse when all ok
 
    output logic [7:0] payload_data,
    output logic payload_valid,
    input logic payload_ready,
 
    output logic rx_syn, //to tcp_session
    output logic rx_ack,
    output logic rx_fin,
    output logic rx_rst,
    output logic csum_error, //pulse when checksum fails
    output logic [5:0] header_len_out
    );
 
typedef enum logic [2:0] {
    idle, header, csum_check, options, csum_final, payload_state
} state_t;
 
state_t state;
logic [4:0] cnt; 
logic [7:0] hdr [0:19]; //raw header byte capture
logic [15:0] rx_checksum;
logic [5:0] header_len; //actual header length in bytes = data_offset * 4
logic [5:0] options_remaining;
logic [7:0] data_offset_raw; //captured hdr[12] for checksum
 
logic [31:0] csum_acc;
logic [7:0] csum_byte_hi;
logic csum_hi_valid;
 
logic [31:0] csum_with_pseudo;
logic [16:0] csum_fold1;
logic [15:0] csum_fold2;
 
assign csum_with_pseudo = csum_acc
    + {16'h0, src_ip[31:16]} + {16'h0, src_ip[15:0]}
    + {16'h0, dst_ip[31:16]} + {16'h0, dst_ip[15:0]}
    + 32'h0006 + {16'h0, tcp_length};
 
assign csum_fold1 = {1'b0, csum_with_pseudo[15:0]} + {1'b0, csum_with_pseudo[31:16]};
assign csum_fold2 = csum_fold1[15:0] + {15'h0, csum_fold1[16]};
 
logic [31:0] csum_acc_imm;
assign csum_acc_imm = csum_acc + {16'h0, csum_byte_hi, data_in};
logic [31:0] csum_with_pseudo_imm;
assign csum_with_pseudo_imm = csum_acc_imm
    + {16'h0, src_ip[31:16]} + {16'h0, src_ip[15:0]}
    + {16'h0, dst_ip[31:16]} + {16'h0, dst_ip[15:0]}
    + 32'h0006 + {16'h0, tcp_length};
logic [16:0] csum_fold1_imm;
assign csum_fold1_imm = {1'b0, csum_with_pseudo_imm[15:0]} + {1'b0, csum_with_pseudo_imm[31:16]};
logic [15:0] csum_fold2_imm;
assign csum_fold2_imm = csum_fold1_imm[15:0] + {15'h0, csum_fold1_imm[16]};
 
always_ff @(posedge rx_clk) begin
    if (rst) begin
        state <= idle;
        cnt <= 0;
        src_port <= 0;
        dst_port <= 0;
        seq_num <= 0;
        ack_num <= 0;
        flags <= 0;
        window_size <= 0;
        rx_checksum <= 0;
        header_len <= 0;
        options_remaining <= 0;
        data_offset_raw <= 0;
        csum_acc <= 0;
        csum_byte_hi <= 0;
        csum_hi_valid <= 0;
        payload_data <= 0;
        payload_valid <= 0;
        data_in_ready <= 0;
        header_valid <= 0;
        rx_syn <= 0;
        rx_ack <= 0;
        rx_fin <= 0;
        rx_rst <= 0;
        csum_error <= 0;
    end else begin
        data_in_ready <= 0;
        header_valid <= 0;
        rx_syn <= 0;
        rx_ack <= 0;
        rx_fin <= 0;
        rx_rst <= 0;
        csum_error <= 0;
 
        unique case (state)
            idle: begin
                payload_valid <= 0;
                cnt <= 0;
                csum_acc <= 0;
                csum_byte_hi <= 0;
                csum_hi_valid <= 0;
                data_in_ready <= 1;
                if (data_in_valid) begin
                    hdr[0] <= data_in;
                    csum_byte_hi <= data_in;
                    csum_hi_valid <= 1;
                    cnt <= 1;
                    state <= header;
                end
            end
 
            header: begin
                data_in_ready <= 1;
                if (data_in_valid) begin
                    hdr[cnt] <= data_in;
                    cnt <= cnt + 1;
                    if (csum_hi_valid) begin
                        csum_acc <= csum_acc + {16'h0, csum_byte_hi, data_in};
                        csum_hi_valid <= 0;
                    end else begin
                        csum_byte_hi <= data_in;
                        csum_hi_valid <= 1;
                    end
                    if (cnt == 19) begin
                        src_port <= {hdr[0], hdr[1]};
                        dst_port <= {hdr[2], hdr[3]};
                        seq_num <= {hdr[4], hdr[5], hdr[6], hdr[7]};
                        ack_num <= {hdr[8], hdr[9], hdr[10], hdr[11]};
                        flags <= hdr[13];
                        window_size <= {hdr[14], hdr[15]};
                        rx_checksum <= {hdr[16], hdr[17]};
                        header_len <= {hdr[12][7:4], 2'b00};
                        options_remaining <= {hdr[12][7:4], 2'b00} - 6'd20;
                        data_offset_raw <= hdr[12];
                        if ({hdr[12][7:4], 2'b00} > 6'd20) begin
                            state <= options;
                        end else begin
                            if (csum_fold2_imm == 16'hFFFF || tcp_length > {10'b0, hdr[12][7:4], 2'b00}) begin
                                header_valid <= 1;
                                rx_syn <= hdr[13][1];
                                rx_ack <= hdr[13][4];
                                rx_fin <= hdr[13][0];
                                rx_rst <= hdr[13][2];
                                if (tcp_length > {10'b0, hdr[12][7:4], 2'b00})
                                    state <= payload_state;
                                else
                                    state <= idle;
                            end else begin
                                csum_error <= 1;
                                state <= idle;
                            end
                        end
                    end
                end
            end
 
            csum_check: begin
                if (options_remaining > 0)
                    state <= options;
                else begin
                    if (csum_fold2 == 16'hFFFF) begin
                        header_valid <= 1;
                        rx_syn <= flags[1];
                        rx_ack <= flags[4];
                        rx_fin <= flags[0];
                        rx_rst <= flags[2];
                        if (tcp_length > header_len)
                            state <= payload_state;
                        else
                            state <= idle;
                    end else begin
                        csum_error <= 1;
                        state <= idle;
                    end
                end
            end
 
            options: begin
                data_in_ready <= 1;
                if (data_in_valid) begin
                    if (csum_hi_valid) begin
                        csum_acc <= csum_acc + {16'h0, csum_byte_hi, data_in};
                        csum_hi_valid <= 0;
                    end else begin
                        csum_byte_hi <= data_in;
                        csum_hi_valid <= 1;
                    end
                    options_remaining <= options_remaining - 1;
                    if (options_remaining == 1) begin
                        if (csum_fold2_imm == 16'hFFFF || tcp_length > {10'b0, header_len}) begin
                            header_valid <= 1;
                            rx_syn <= flags[1];
                            rx_ack <= flags[4];
                            rx_fin <= flags[0];
                            rx_rst <= flags[2];
                            if (tcp_length > {10'b0, header_len})
                                state <= payload_state;
                            else
                                state <= idle;
                        end else begin
                            csum_error <= 1;
                            state <= idle;
                        end
                    end
                end
            end
 
            csum_final: begin
                if (csum_fold2 == 16'hFFFF) begin
                    header_valid <= 1;
                    rx_syn <= flags[1];
                    rx_ack <= flags[4];
                    rx_fin <= flags[0];
                    rx_rst <= flags[2];
                    if (tcp_length > header_len)
                        state <= payload_state;
                    else
                        state <= idle;
                end else begin
                    csum_error <= 1;
                    state <= idle;
                end
            end
 
            payload_state: begin
                data_in_ready <= payload_ready;
                payload_valid <= data_in_valid;
                if (data_in_valid && payload_ready) begin
                    payload_data <= data_in;
                end
                if (data_in_last) begin
                    state <= idle;
                end
            end
        endcase
    end
end
 
assign header_len_out = header_len;
endmodule
 
