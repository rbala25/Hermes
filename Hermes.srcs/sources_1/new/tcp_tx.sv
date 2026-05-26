`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 02:48:57 PM
// Design Name: 
// Module Name: tcp_tx
// Project Name: 
// Target Devices: Arty A7 35t 
// Tool Versions: 
// Description: for iLink3 tx side
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tcp_tx(
    input logic tx_clk,
    input logic rst,

    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [15:0] tcp_length, //20 + payload length

    input logic [15:0] src_port, //header fields
    input logic [15:0] dst_port,
    input logic [31:0] ack_num,
    input logic [7:0] flags, //0x02 - syn, 0x10 - ack, 0x18 - ack + psh
    input logic [15:0] window_size,

    input logic [15:0] payload_csum,

    input logic [31:0] init_seq,
    input logic load_seq, //one cycle pulse

    input logic start,
    output logic done,

    input logic [7:0] payload_in_data, //from ilink_tx
    input logic payload_in_valid,
    output logic payload_in_ready,

    output logic [7:0] payload_data, //to ip_tx
    output logic payload_valid,
    input logic payload_ready
    );
    
logic [31:0] seq_num;

logic [31:0] csum_static; //protocol for TCP is num 6
assign csum_static = {16'h0, src_ip[31:16]} + {16'h0, src_ip[15:0]} + {16'h0, dst_ip[31:16]} + {16'h0, dst_ip[15:0]} + 32'h0006 + {16'h0, tcp_length}
                   + {16'h0, src_port} + {16'h0, dst_port} + {16'h0, seq_num[31:16]} + {16'h0, seq_num[15:0]} + {16'h0, ack_num[31:16]}
                   + {16'h0, ack_num[15:0]} + {16'h0, {8'h50, flags}} + {16'h0, window_size};
//0x5000 = data_offset 5 << 12; urgent ptr and checksum placeholder are zero

logic [16:0] csum_fold1;
logic [15:0] csum_fold2;
logic [16:0] csum_with_payload;
logic [15:0] csum_prefinal;
logic [15:0] checksum;

assign csum_fold1 = {1'b0, csum_static[15:0]} + {1'b0, csum_static[31:16]};
assign csum_fold2 = csum_fold1[15:0] + {15'h0, csum_fold1[16]};
assign csum_with_payload = {1'b0, csum_fold2} + {1'b0, payload_csum};
assign csum_prefinal = csum_with_payload[15:0] + {15'h0, csum_with_payload[16]};
assign checksum = ~csum_prefinal;

typedef enum logic [1:0] {
    idle, header, data
} state_t;

state_t state;
logic [4:0] cnt;
logic [15:0] byte_cnt;

always_ff @(posedge tx_clk) begin
    if (rst) begin
        state <= idle;
        cnt <= 0;
        seq_num <= 0;
        byte_cnt <= 0;
        payload_data <= 0;
        payload_valid <= 0;
        payload_in_ready <= 0;
        done <= 0;
    end else begin
        payload_in_ready <= 0;
        done <= 0;

        unique case (state)
            idle: begin
                payload_valid <= 0;
                cnt <= 0;
                byte_cnt <= 0;
                if (start) begin
                    payload_data <= src_port[15:8]; //preload
                    payload_valid <= 1;
                    cnt <= 1;
                    state <= header;
                end
            end

            header: begin
                payload_valid <= 1;
                if (payload_ready) begin
                    cnt <= cnt + 1;
                    unique case (cnt)
                        5'd1:  payload_data <= src_port[7:0];
                        5'd2:  payload_data <= dst_port[15:8];
                        5'd3:  payload_data <= dst_port[7:0];
                        5'd4:  payload_data <= seq_num[31:24];
                        5'd5:  payload_data <= seq_num[23:16];
                        5'd6:  payload_data <= seq_num[15:8];
                        5'd7:  payload_data <= seq_num[7:0];
                        5'd8:  payload_data <= ack_num[31:24];
                        5'd9:  payload_data <= ack_num[23:16];
                        5'd10: payload_data <= ack_num[15:8];
                        5'd11: payload_data <= ack_num[7:0];
                        5'd12: payload_data <= 8'h50; //data_offset=5, reserved=0
                        5'd13: payload_data <= flags;
                        5'd14: payload_data <= window_size[15:8];
                        5'd15: payload_data <= window_size[7:0];
                        5'd16: payload_data <= checksum[15:8];
                        5'd17: payload_data <= checksum[7:0];
                        5'd18: payload_data <= 8'h00; //urgent ptr
                        5'd19: begin
                            payload_data <= 8'h00; //urgent ptr
                            state <= data;
                        end
                        default: payload_data <= 8'h00;
                    endcase
                end
            end

            data: begin
                if (payload_in_valid) payload_valid <= 1;
                if (payload_ready && payload_in_valid) begin
                    payload_data <= payload_in_data;
                    payload_in_ready <= 1;
                    byte_cnt <= byte_cnt + 1;
                end

                if (payload_ready && !payload_in_valid) begin
                    seq_num <= seq_num + {16'h0, byte_cnt} + (flags[1] ? 32'd1 : 32'd0) + (flags[0] ? 32'd1 : 32'd0); //syn flag then fin flag
                    done <= 1;
                    payload_valid <= 0;
                    state <= idle;
                end
            end
        endcase
        
        if (load_seq) seq_num <= init_seq; //load_seq wins over any seq_num update above
    end
end

endmodule
