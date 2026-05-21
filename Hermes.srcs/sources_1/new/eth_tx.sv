`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 12:04:00 PM
// Design Name: 
// Module Name: eth_tx
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


module eth_tx(
    input logic tx_clk,
    input logic rst,

    input logic [47:0] dst_mac, //for ip/icmp
    input logic [15:0] ether_type,
    input logic [7:0] payload_data,
    input logic payload_valid,
    input logic start,
    output logic payload_ready,
    output logic done,

    output logic [7:0] txd, //for mii
    output logic tx_valid,
    input logic tx_ready
    );
    
localparam logic [47:0] SRC = 48'h00183E03E41B;

typedef enum logic [2:0] {
    idle, dst, src, ether, payload
} state_t;

state_t state;
logic [2:0] cnt;

always_ff @(posedge tx_clk) begin
    if(rst) begin
        state <= idle;
        cnt <= 0;
        txd <= 0;
        tx_valid <= 0;
        payload_ready <= 0;
        done <= 0;
    end else begin
        tx_valid <= 0;
        payload_ready <= 0;
        done <= 0;
        
        unique case (state)
            idle: begin
                cnt <= 0;
                if(start) begin
                    state <= dst;
                    txd <= dst_mac[47:40]; //drive first byte
                    tx_valid <= 1;
                    cnt <= 1;
                end
            end
            
            dst: begin
                if (tx_ready) begin
                    if(cnt < 5) begin
                        txd <= dst_mac[47 - cnt*8 -: 8];
                        tx_valid <= 1;
                        cnt <= cnt + 1;
                    end else begin
                        txd <= dst_mac[7:0];
                        cnt <= 0;
                        tx_valid <= 1;
                        state <= src;
                    end
                end
            end
            
            src: begin
                if (tx_ready) begin
                    if(cnt < 5) begin
                        txd <= SRC[47 - cnt*8 -: 8];
                        tx_valid <= 1;
                        cnt <= cnt + 1;
                    end else begin
                        txd <= SRC[7:0];
                        cnt <= 0;
                        tx_valid <= 1;
                        state <= ether;
                    end
                end
            end
            
            ether: begin
                if(tx_ready) begin
                    tx_valid <= 1;
                    if(cnt) begin
                        txd <= ether_type[7:0];
                        cnt <= 0;
                        state <= payload;
                       //  payload_ready <= 1; mii takes 2 cycles for every byte
                    end else begin
                        txd <= ether_type[15:8];
                        cnt <= cnt + 1;
                    end
                end
            end
            
            payload: begin
                if(tx_ready && payload_valid) begin
                    tx_valid <= 1;
                    txd <= payload_data;
                    payload_ready <= 1;
                end
                
                if(tx_ready && !payload_valid) begin
                    done <= 1;
                    state <= idle;
                end
            end
        endcase  
    end
end    
endmodule
