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
        
        unique case (state) 
            idle: begin
                if(error) begin
                    udp_error <= 1;
                    state <= idle;
                    cnt <= 0;
                end
            
            end
        
        endcase
    end
end
endmodule
