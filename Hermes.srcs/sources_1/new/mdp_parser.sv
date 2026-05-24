`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/24/2026 12:04:08 AM
// Design Name: 
// Module Name: mdp_parser
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


module mdp_parser #(
    parameter logic [15:0] port = 16'd14310,
    parameter logic [31:0] sec_id = 32'd0 //imaginary
)(
    input logic clk,
    input logic rst,

    input logic [7:0] udp_payload,//from udp
    input logic udp_payload_valid,
    input logic udp_payload_done,
    input logic udp_header_valid,
    input logic [15:0] udp_dest,
    input logic udp_error,

    output logic [31:0] mdp_seq_num,
    output logic [63:0] mdp_sending_time,
    output logic mdp_pkt_valid, //pulse when header done (the 12 bit header)

    output logic [63:0] entry_price, //MDEntryPx PRICE9 (10^9)
    output logic [31:0] entry_size, 
//    output logic [31:0] entry_security_id, //security id
    output logic [7:0] entry_price_level, //md price level 1-10
    output logic [7:0] entry_update_action, //0 = new, 1 = change, 2 = delete
    output logic [7:0] entry_type, //0x30=Bid 0x31=Ask
//    output logic [15:0] entry_template_id, // 46=incremental 38=snapshot
    output logic is_snapshot,
    output logic entry_valid, //pulses for each entry WITHIN an SBE (can be multiple depending on msg size)
    output logic mdp_done, //all SBEs done
    output logic mdp_error
);

typedef enum logic [3:0] {
    idle,
    seq,
    mdp_time,
    size,
    hdr,
    root_46,
    dimensions_46,
    entry_46,
    root_38,
    dimensions_38,
    entry_38,
    skip
} state_t;

state_t state;

logic active;
logic [7:0] cnt;
logic [7:0] entries_left;
logic [15:0] entry_blk_len;
logic [15:0] msg_size; //total SBE message size
logic [15:0] root_blk_len; //root block size
logic [15:0] template_id;
logic [15:0] msg_body_remaining;
logic [15:0] skip_remaining;
logic [31:0] t38_sec_id;
logic cur_sec_id;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= idle;
        active <= 0;
        cnt <= 0;
        entries_left <= 0;
        entry_blk_len <= 0;
        msg_size <= 0;
        root_blk_len <= 0;
        template_id <= 0;
        msg_body_remaining <= 0;
        skip_remaining <= 0;
        t38_sec_id <= 0;
        cur_sec_id <= 0;
        mdp_seq_num <= 0;
        mdp_sending_time <= 0;
        mdp_pkt_valid <= 0;
        entry_price <= 0;
        entry_size <= 0;
        entry_price_level <= 0;
        entry_update_action <= 0;
        entry_type <= 0;
        is_snapshot <= 0;
        entry_valid <= 0;
        mdp_done <= 0;
        mdp_error <= 0;
    end else begin
        mdp_pkt_valid <= 0;
        entry_valid <= 0;
        mdp_done <= 0;
        mdp_error <= 0;
        
        if (udp_error) begin
            state <= idle;
            active <= 0;
            mdp_error <= 1;
        end else if (udp_header_valid) begin
            if (udp_dest == port) begin
                active <= 1;
                state <= seq;
                cnt <= 0;
            end else
                active <= 0;
        end else if (udp_payload_valid && active) begin
            unique case (state)
                idle: ;
                
                seq: begin
                    mdp_seq_num <= {udp_payload, mdp_seq_num[31:8]};
                    cnt <= cnt + 1;
                    if (cnt >= 3) begin
                        cnt <= 0;
                        state <= mdp_time;
                    end
                end
                
                mdp_time: begin
                    mdp_sending_time <= {udp_payload, mdp_sending_time[63:8]};
                    cnt <= cnt + 1;
                    if (cnt == 7) begin
                        cnt <= 0;
                        mdp_pkt_valid <= 1;
                        if (udp_payload_done) begin
                            state <= idle;
                            active <= 0;
                            mdp_done <= 1;
                        end else
                            state <= size;
                    end
                end
            
            endcase
        end
    end
end

endmodule
