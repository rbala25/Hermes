`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: udp_parser
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


module udp_parser(
    input logic clk,
    input logic rst,
    input logic payload_valid, //from ip_parser
    input logic ip_header_valid,
    input logic ip_payload_done,
    input logic error,
    input logic [7:0] ip_protocol,
    input logic [7:0] payload_data,
    input logic [31:0] ip_src,
    input logic [31:0] ip_dest,
    
    output logic [15:0] udp_src, //parsed outputs
    output logic [15:0] udp_dest,
    output logic [15:0] udp_length, //including 8 bit header
    output logic [15:0] udp_checksum,
    output logic udp_header_valid,
    output logic udp_checksum_val,
    output logic [7:0] udp_payload,
    output logic udp_payload_valid,
    output logic udp_payload_done,
    output logic udp_error
    );
    
typedef enum logic [2:0] {
    idle,
    src,
    dest,
    length,
    chksum,
    payload
} state_t;

state_t state;
logic cnt;

logic [7:0] checksum_in;
logic [15:0] checksum;
logic phase;

logic [16:0] next;
always_comb begin
    next = {1'b0, checksum} + {1'b0, checksum_in, payload};
    if (next[16]) next = {1'b0, next[15:0]} + 17'h1;
end

logic [16:0] next_odd; //if no final byte, spec says pad with 0x00
always_comb begin
    next_odd = {1'b0, checksum} + {1'b0, payload, 8'h00};
    if (next_odd[16]) next_odd = {1'b0, next_odd[15:0]} + 17'h1;
end

logic [16:0] next_double; //length needs to be added twice (field + pseudo)
always_comb begin
    next_double = {1'b0, next[15:0]} + {1'b0, checksum_in, payload};
    if (next_double[16]) next_double = {1'b0, next_double[15:0]} + 17'h1;
end

//pre calculate the psuedo header: 0x11 = protocol for udp
logic [19:0] ph_raw = {4'b0, ip_src[31:16]} + {4'b0, ip_src[15:0]} + {4'b0, ip_dest[31:16]} + {4'b0, ip_dest[15:0]} + 20'h00011;
logic [16:0] ph_fold1 = {1'b0, ph_raw[15:0]} + {1'b0, ph_raw[19:16]};
logic [15:0] ph_seed = ph_fold1[15:0] + {15'b0, ph_fold1[16]};

always_ff @(posedge clk) begin //synchronous, active high resets
    if(rst) begin
        state <= idle;
        cnt <= 0;
        udp_src <= 0;
        udp_dest <= 0;
        udp_length <= 0;
        udp_checksum <= 0;
        udp_header_valid <= 0;
        udp_checksum_val <= 0;
        udp_payload <= 0;
        udp_payload_valid <= 0;
        udp_payload_done <= 0;
        udp_error <= 0;
        checksum <= 0;
        checksum_in <= 0;
        phase <= 0;
    end else begin
        udp_header_valid <= 0;
        udp_payload_valid <= 0;
        udp_payload_done <= 1;
        udp_error <= 0;
        
        if(error) begin
            udp_error <= 1;
            state <= idle;
            cnt <= 0;
        end else if (ip_header_valid) begin
            if(ip_protocol == 8'h11) begin
                checksum <= ph_seed;
                phase <= 0;
                cnt <= 0;
                state <= src;
            end
        end else if (payload_valid) begin
        
            if(state != idle && state != payload) begin
                if(!phase) checksum_in <= payload;
                else checksum <= next[15:0];
                phase <= ~phase;
            end
        
            unique case (state)
                idle: ;
                
                src: begin
                    udp_src <= {udp_src[7:0], payload_data};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        cnt <= 0;
                        state <= dest;
                    end
                end
                
                dest: begin
                    udp_dest <= {udp_dest[7:0], payload_data};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        cnt <= 0;
                        state <= length;
                    end
                end
                
                length: begin
                    udp_length <= {udp_length[7:0], payload};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        checksum <= next_double[15:0];
                        cnt <= 0;
                        state <= length;
                    end
                end
                
                chksum: begin
                    udp_checksum <= {udp_checksum[7:0], payload};
                    cnt <= cnt + 1;
                    if (cnt) begin
                        cnt <= 0;
                        state <= payload;
                        udp_header_valid <= 1;
                    end
                end
                
                payload: begin
                    udp_payload <= payload;
                    udp_payload_valid <= 1;
                    
                    if(ip_payload_done) begin
                        udp_payload_done <= 1;
                        state <= idle;
                        phase <= 0;
                        if(!phase) begin
                           udp_checksum_val <= (next_odd[15:0] == 16'hFFFF) || (udp_checksum == 16'h0000);
                        end else begin
                            udp_checksum_val <= (next[15:0] == 16'hFFFF) || (udp_checksum == 16'h0000);
                        end
                    end else begin
                        if(!phase) checksum_in <= payload;
                        else checksum <= next[15:0];
                        phase <= ~phase;
                    end
                end
                
                default: state <= idle;
            endcase
        end
    end
end
endmodule
