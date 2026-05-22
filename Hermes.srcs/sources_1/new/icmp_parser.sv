`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/20/2026 05:27:32 PM
// Design Name: 
// Module Name: icmp_parser
// Project Name: 
// Target Devices: 
// Tool Versions: Arty A7 35t
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module icmp_parser(
    input logic clk,
    input logic rst,
    input logic [7:0] payload,
    input logic payload_valid,
    input logic ip_header_valid,
    input logic ip_payload_done,
    input logic [7:0] ip_protocol,
    input logic error,
 
    output logic [7:0] icmp_type,
    output logic [7:0] icmp_code,
    output logic [15:0] icmp_checksum,
    output logic [15:0] icmp_identifier, //echo only
    output logic [15:0] icmp_seq_num, //echo only
    output logic icmp_header_valid, 
    output logic icmp_checksum_val,
    output logic [7:0] icmp_payload_data,
    output logic icmp_payload_valid,
    output logic icmp_payload_done,
    output logic icmp_error
    );
    
    typedef enum logic [3:0] { 
        idle,
        s_type,
        code,
        cksum,
        rest0,
        rest1,
        rest2,
        rest3,
        s_payload
    } state_t;
 
    state_t state;
    logic cnt;
    logic [7:0] r_type;
    
    logic [7:0] checksum_in;
    logic [15:0] checksum;
    logic phase;
    
    logic [16:0] next;
    always_comb begin
        next = {1'b0, checksum} + {1'b0, checksum_in, payload};
        if (next[16]) next = {1'b0, next[15:0]} + 17'h1;
    end
    
    logic [16:0] next_odd; //final byte for payload of odd length
    always_comb begin
        next_odd = {1'b0, checksum} + {1'b0, checksum_in, 8'h00};
        if (next_odd[16]) next_odd = {1'b0, next_odd[15:0]} + 17'h1;
    end
    
    always_ff @(posedge clk) begin
         if (rst) begin
            state              <= idle;
            cnt                <= 0;
            r_type             <= 0;
            icmp_type          <= 0;
            icmp_code          <= 0;
            icmp_checksum      <= 0;
            icmp_identifier    <= 0;
            icmp_seq_num       <= 0;
            icmp_header_valid  <= 0;
            icmp_checksum_val  <= 0;
            icmp_payload_data  <= 0;
            icmp_payload_valid <= 0;
            icmp_payload_done  <= 0;
            icmp_error         <= 0;
            checksum           <= 0;
            checksum_in        <= 0;
            phase              <= 0;
        end else begin
            icmp_header_valid  <= 0;
            icmp_payload_valid <= 0;
            icmp_payload_done  <= 0;
            icmp_checksum_val  <= 0;
            
            if(error) begin
                icmp_error <= 1;
                state <= idle;
            end
            
            unique case (state) 
                idle: begin
                    icmp_error <= 0;
                    
                    if(ip_header_valid && (ip_protocol == 8'h01)) begin
                        checksum <= 0;
                        phase <= 0;
                        state <= s_type;
                    end
                end
                
                s_type: begin //byte 0
                    if (payload_valid) begin
                        icmp_type <= payload;
                        r_type <= payload;
                        
                        checksum_in <= payload;
                        state <= code;
                    end
                end
                
                code: begin
                    if (payload_valid) begin
                        icmp_code <= payload;

                        checksum <= next[15:0];
                        checksum_in <= 0;
                        state <= cksum;
                        cnt <= 0;
                    end
                end
                
                cksum: begin
                    if (payload_valid) begin
                        if (!cnt) begin
                            icmp_checksum[15:8] <= payload;
                            checksum_in <= payload;
                            cnt <= 1;
                        end else begin
                            icmp_checksum[7:0] <= payload;
                            checksum <= next[15:0];
                            checksum_in <= 0;
                            cnt <= 0;
                            state <= rest0;
                        end
                    end
                end
                
                rest0: begin //byte 4: echo req (0x08) or echo reply (0x00) identifier high bit
                    if (payload_valid) begin
                        if (r_type == 8'h00 || r_type == 8'h08) //shoudlnt read outputs directly, so use r_type
                            icmp_identifier[15:8] <= payload;
                        checksum_in <= payload;
                        state <= rest1;
                    end
                end
                
                rest1: begin
                    if (payload_valid) begin
                        if (r_type == 8'h00 || r_type == 8'h08) 
                            icmp_identifier[7:0] <= payload;
                        checksum <= next[15:0];
                        checksum_in <= 0;
                        state <= rest2;
                    end
                end
                
                rest2: begin //seq number
                    if (payload_valid) begin
                        if (r_type == 8'h00 || r_type == 8'h08)
                            icmp_seq_num[15:8] <= payload;
                        checksum_in <= payload;
                        state <= rest3;
                    end
                end
                
                rest3: begin
                    if (payload_valid) begin
                        if (r_type == 8'h00 || r_type == 8'h08) 
                            icmp_seq_num[7:0] <= payload;
                        checksum <= next[15:0];
                        checksum_in <= 0;
                        icmp_header_valid <= 1;
                        phase <= 0;
                        state <= s_payload;
                        $display("ICMP: header_valid, type=%02X code=%02X id=%04X seq=%04X t=%0t", icmp_type, icmp_code, icmp_identifier, {icmp_seq_num[15:8],payload}, $time); 
                    end
                end
                
                s_payload: begin
                    if (payload_valid) begin
                        icmp_payload_data <= payload;
                        icmp_payload_valid <= 1;
                        if (!phase) begin
                            checksum_in <= payload;
                            phase <= ~phase;
                        end else begin
                            checksum <= next[15:0];
                            checksum_in <= 0;
                            phase <= ~phase;
                        end
                    end
                    
                    if (ip_payload_done) begin 
                        icmp_payload_done <= 1;
                        if (phase) checksum <= next_odd[15:0];
                        icmp_checksum_val <= (checksum == 16'hFFFF);
                        state <= idle;
                    end
                end
            endcase
        end
    end
endmodule
