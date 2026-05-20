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
    output logic udp_checksum_valid,
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
    checksum,
    payload
} state_t;

state_t state;
logic cnt;

logic [31:0] chksum_acc;
logic [7:0] checksum_in;
logic byte_pending;

always_ff @(posedge clk) begin //synchronous, active high resets
    if(rst) begin
        state <= idle;
        cnt <= 0;
        udp_src <= 0;
        udp_dest <= 0;
        udp_length <= 0;
        udp_checksum <= 0;
        udp_header_valid <= 0;
        udp_checksum_valid <= 0;
        udp_payload <= 0;
        udp_payload_valid <= 0;
        udp_payload_done <= 0;
        udp_error <= 0;
        chksum_acc <= 0;
        checksum_in <= 0;
        byte_pending <= 0;
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
                chksum_acc <= ip_src[31:16] + ip_src[15:0] + ip_dest[31:16] + ip_dest[15:0] + ip_protocol;
                byte_pending <= 0;
                cnt <= 0;
                state <= src;
            end
        end else if (payload_valid) begin
            unique case (state)
                idle: ;
                
                src: begin
                    udp_src <= {udp_src[7:0], payload_data};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        chksum_acc <= chksum_acc + {udp_src[7:0], payload};
                        cnt <= 0;
                        state <= dest;
                    end
                end
                
                dest: begin
                    udp_dest <= {udp_dest[7:0], payload_data};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        chksum_acc <= chksum_acc + {udp_dest[7:0], payload};
                        cnt <= 0;
                        state <= length;
                    end
                end
                
                length: begin
                    udp_length <= {udp_length[7:0], payload};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        chksum_acc <= chksum_acc + (2*{udp_length[7:0], payload});
                        cnt <= 0;
                        state <= length;
                    end
                end
                
                checksum: begin
                    udp_checksum <= {udp_checksum[7:0], payload};
                    cnt <= cnt + 1;
                    if (cnt) begin
                        chksum_acc <= chksum_acc + {udp_checksum[7:0], payload};
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
                        if(byte_pending) begin
                            chksum_acc <= chksum_acc + {checksum_in, payload};
                            byte_pending <= 0;
                        end else begin
                            chksum_acc <= chksum_acc + {payload, 8'h0}; //padding according to spec
                        end
                    end
                    
                end
            endcase
        end
    end
end
endmodule
