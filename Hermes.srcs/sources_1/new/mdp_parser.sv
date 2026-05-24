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
    parameter logic [31:0] sec_id = 32'd0 //arbitrary
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
//    dimensions_46,
    entry_46,
    root_38,
//    dimensions_38,
    entry_38,
    dimensions,
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
logic [31:0] cur_sec_id;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= idle;
        active <= 0;
        cnt <= 0;
        entries_left <= 0; //dimensions tells us entries per sbe
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
                    if (cnt == 3) begin
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
                
                //sbe
                size: begin
                    msg_size <= {udp_payload, msg_size[15:8]};
                    cnt <= cnt + 1;
                    if (cnt == 1) begin
                        cnt <= 0;
                        state <= hdr;
                    end
                end
                
                hdr: begin
                    cnt <= cnt + 1;
                    if (cnt == 0 || cnt == 1)
                        root_blk_len <= {udp_payload, root_blk_len[15:8]};
                    if (cnt == 2 || cnt == 3)
                        template_id <= {udp_payload, template_id[15:8]};
                    //skip bytes 4-5 schema id
                    if (cnt == 7) begin //skip byte 7 (version)
                        cnt <= 0;
                        msg_body_remaining <= msg_size - 16'd10;
                        case (template_id)
                            16'd46: begin
                                is_snapshot <= 0;
                                state <= root_46;
                            end
                            16'd38: begin
                                is_snapshot <= 1;
                                state <= root_38;
                            end
                            default: begin
                                state <= skip;
                                skip_remaining <= msg_size - 16'd10;
                            end
                        endcase
                    end
                end
            
                //t46
                root_46: begin
                    cnt <= cnt + 1;
                    if (cnt == root_blk_len[7:0] - 1) begin //ignoring contents, just counting
                        cnt <= 0;
                        msg_body_remaining <= msg_body_remaining - root_blk_len;
                        state <= dimensions;
                    end
                end
                
//                dimensions_46: begin
//                    cnt <= cnt + 1;
//                    if (cnt == 0 || cnt == 1) //how big is each entry
//                        entry_blk_len <= {udp_payload, entry_blk_len[15:8]};
//                    if (cnt == 2) begin
//                        cnt <= 0;
//                        msg_body_remaining <= msg_body_remaining - 16'd3; 
//                        if (udp_payload == 0) begin
//                            //no entries
//                            if (msg_body_remaining == 3) begin
//                                if (udp_payload_done) begin
//                                    state <= idle;
//                                    active <= 0; //end
//                                    mdp_done <= 1;
//                                end 
////                              else state <= size; //next sbe
//                            end else begin
//                                state <= skip;
//                                skip_remaining <= msg_body_remaining - 16'd3;
//                            end
//                        end else begin
//                            entries_left <= udp_payload; //num of entries
//                            state <= entry_46;
//                        end
//                    end
//                end
                
                entry_46: begin
                    cnt <= cnt + 1;
                    if (cnt < 8) //price9 mantissa
                        entry_price <= {udp_payload, entry_price[63:8]};
                    else if (cnt < 12) //num of contracts at this price
                        entry_size <= {udp_payload, entry_size[31:8]};
                    else if (cnt < 16)
                        cur_sec_id <= {udp_payload, cur_sec_id[31:8]};
                    else if (cnt == 24) 
                        entry_price_level <= udp_payload;
                    else if (cnt == 25) //new change delete
                        entry_update_action <= udp_payload;
                    else if (cnt == 26) //bid or ask
                        entry_type <= udp_payload;
                        
                    if (cnt == entry_blk_len[7:0] - 1) begin
                        cnt <= 0;
                        entries_left <= entries_left - 1;
                        msg_body_remaining <= msg_body_remaining - entry_blk_len;
                        if (cur_sec_id == sec_id) entry_valid <= 1;
                        if (entries_left == 1) begin //else stay in entry state
                            if (msg_body_remaining == entry_blk_len) begin
                                if (udp_payload_done) begin
                                    state <= idle; 
                                    active <= 0; 
                                    mdp_done <= 1;
                                end else
                                    state <= size;
                            end else begin
                                state <= skip;
                                skip_remaining <= msg_body_remaining - entry_blk_len;
                            end
                        end
                    end
                end
                
                //t38
                root_38: begin
                    cnt <= cnt + 1;
                    if (cnt >= 8 && cnt <= 11) //skip most fields (53 bytes total)
                        t38_sec_id <= {udp_payload, t38_sec_id[31:8]};
                    if (cnt == root_blk_len[7:0] - 1) begin
                        cnt <= 0;
                        msg_body_remaining <= msg_body_remaining - root_blk_len;
                        if (t38_sec_id != sec_id) begin //skip rest
                            state <= skip;
                            skip_remaining <= msg_body_remaining - root_blk_len;
                        end else
                            state <= dimensions;
                    end
                end
                
//                dimensions_38: begin //technically same as dimensions_46 aside from next state
//                    cnt <= cnt + 1;
//                    if (cnt == 0 || cnt == 1)
//                        entry_blk_len <= {udp_payload, entry_blk_len[15:8]};
//                    if (cnt == 2) begin
//                        cnt <= 0;
//                        msg_body_remaining <= msg_body_remaining - 16'd3;
//                        if (udp_payload == 0) begin
//                            if (msg_body_remaining == 3) begin
//                                if (udp_payload_done) begin
//                                    state <= idle; 
//                                    active <= 0; 
//                                    mdp_done <= 1;
//                                end 
////                                else state <= size;
//                            end else begin
//                                state <= skip;
//                                skip_remaining <= msg_body_remaining - 16'd3;
//                            end
//                        end else begin
//                            entries_left <= udp_payload;
//                            state <= entry_38;
//                        end
//                    end
//                end
                
                entry_38: begin
                    cnt <= cnt + 1;
                    if (cnt <= 7) //entry price
                        entry_price <= {udp_payload, entry_price[63:8]};
                    else if (cnt <= 11) //num of contracts  
                        entry_size <= {udp_payload, entry_size[31:8]};
                    // (skip num orders)
                    else if (cnt == 16) // price level
                        entry_price_level <= udp_payload;
                    else if (cnt == 21) //entry type (bid or ask)
                        entry_type <= udp_payload;

                    if (cnt == entry_blk_len[7:0] - 1) begin
                        cnt <= 0;
                        entry_update_action <= 8'h00; // snapshot always New
                        entry_valid <= 1;
                        entries_left <= entries_left - 1;
                        msg_body_remaining <= msg_body_remaining - entry_blk_len;
                        if (entries_left == 1) begin
                            if (msg_body_remaining == entry_blk_len) begin
                                if (udp_payload_done) begin
                                    state <= idle; 
                                    active <= 0;
                                    mdp_done <= 1;
                                end else
                                    state <= size;
                            end else begin
                                state <= skip;
                                skip_remaining <= msg_body_remaining - entry_blk_len;
                            end
                        end
                    end
                end
                
                //dim
                dimensions: begin
                    cnt <= cnt + 1;
                    if (cnt == 0 || cnt == 1)
                        entry_blk_len <= {udp_payload, entry_blk_len[15:8]};
                    if (cnt == 2) begin
                        cnt <= 0;
                        msg_body_remaining <= msg_body_remaining - 16'd3;
                        if (udp_payload == 0) begin
                            if (udp_payload_done) begin
                                state <= idle; 
                                active <= 0; 
                                mdp_done <= 1;
                            end else
                                state <= size;
                        end else begin
                            entries_left <= udp_payload;
                            state <= (template_id == 16'd46) ? entry_46 : entry_38;
                        end
                    end
                end
                
                skip: begin //skip current sbe
                    skip_remaining <= skip_remaining - 1;
                    if (skip_remaining == 1) begin
                        if (udp_payload_done) begin
                            state <= idle; 
                            active <= 0; 
                            mdp_done <= 1;
                        end else begin
                            state <= size;
                            cnt <= 0;
                        end
                    end
                end
                
                default: state <= idle;
            endcase
        end
    end
end

endmodule
