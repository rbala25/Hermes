`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 01:43:51 PM
// Design Name: 
// Module Name: icmp_tx
// Project Name: 
// Target Devices: 
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


module icmp_tx(
    input logic tx_clk,
    input logic rst,

    input logic [15:0] identifier,
    input logic [15:0] seq,
    input logic [15:0] icmp_checksum, //has to be computed in top

    input logic start,
    output logic done,

    input logic [7:0] payload_in_data,
    input logic payload_in_valid,
    output logic payload_in_ready,

    output logic [7:0] payload_data, //for ip_tx
    output logic payload_valid,
    input logic payload_ready
    );
    
typedef enum logic [1:0] {
    idle, header, data
} state_t;

state_t state;
logic [2:0] cnt;

always_ff @(posedge tx_clk) begin
    if(rst) begin
        state <= idle;
        cnt <= 0;
        payload_data <= 0;
        payload_valid <= 0;
        payload_in_ready <= 0;
        done <= 0;
    end else begin
        payload_valid <= 0;
        payload_in_ready <= 0;
        done <= 0;
        
        
        unique case (state) 
            idle: begin
                cnt <= 0;
                if(start) begin
                    payload_data <= 8'h08;
                    payload_valid <= 1;
                    cnt <= 1;
                    state <= header;
                end
            end
            
            header: begin
                if (payload_ready) begin
                    payload_valid <= 1;
                    cnt <= cnt + 1;
                    
                    unique case (cnt)
                        3'd1: payload_data <= 8'h00; //code
                        3'd2: payload_data <= icmp_checksum[15:8]; //checksum
                        3'd3: payload_data <= icmp_checksum[7:0]; 
                        3'd4: payload_data <= identifier[15:8]; //id
                        3'd5: payload_data <= identifier[7:0];
                        3'd6: payload_data <= seq[15:8]; 
                        3'd7: begin
                            payload_data <= seq[7:0];
                            state        <= data;
                        end
                        default: payload_data <= 8'h00;
                    endcase
                end
            end
            
            data: begin
                if(payload_ready && payload_in_valid) begin
                    payload_data <= payload_in_data;
                    payload_valid <= 1;
                    payload_in_ready <= 1;
                end
                
                if(payload_ready && !payload_in_valid) begin
                    done <= 1;
                    state <= idle;
                end
            end
        endcase
    end
end
endmodule
