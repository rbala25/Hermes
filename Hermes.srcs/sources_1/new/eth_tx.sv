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

function automatic [31:0] crc32_byte(input [31:0] crc_in, input [7:0] data); //according to spec
    logic [31:0] c;
    c = crc_in;
    for (int i = 0; i < 8; i++) begin
        if (c[0] ^ data[i]) c = {1'b0, c[31:1]} ^ 32'hEDB88320;
        else c = {1'b0, c[31:1]};
    end
    return c;
endfunction

typedef enum logic [2:0] {
    idle, dst, src, ether, payload, fcs
} state_t;

state_t state;
logic [2:0] cnt;

logic [31:0] crc_reg;
logic [31:0] fcs_latch;
logic [1:0] fcs_cnt;
logic [5:0] pl_cnt;

logic [31:0] crc_next;
assign crc_next = crc32_byte(crc_reg, txd);

always_ff @(posedge tx_clk) begin
    if(rst) begin
        state <= idle;
        cnt <= 0;
        txd <= 0;
        tx_valid <= 0;
        payload_ready <= 0;
        done <= 0;
        crc_reg <= 32'hFFFFFFFF; 
        fcs_latch <= 0; 
        fcs_cnt <= 0; 
        pl_cnt <= 0;
    end else begin
        tx_valid <= 0;
        payload_ready <= 0;
        done <= 0;
        
        unique case (state)
            idle: begin
                cnt <= 0;
                pl_cnt <= 0;
                if(start) begin
//                    $display("ETH_TX: start fired t=%0t", $time);
                    state <= dst;
                    txd <= dst_mac[47:40]; //drive first byte
                    tx_valid <= 1;
                    cnt <= 1;
                    crc_reg <= 32'hFFFFFFFF; //initial
                end
            end
            
            dst: begin
                tx_valid <= 1;
                if (tx_ready) begin
                    crc_reg <= crc_next;
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
                tx_valid <= 1;
                if (tx_ready) begin
                    crc_reg <= crc_next;
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
                tx_valid <= 1;
                if(tx_ready) begin
                    crc_reg <= crc_next;
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
                tx_valid <= 1;
                if (tx_ready) begin
                    crc_reg <= crc_next;
                    if (payload_valid) begin
                        txd <= payload_data;
                        payload_ready <= 1;
                        if (pl_cnt < 46) pl_cnt <= pl_cnt + 1;
                    end else if (pl_cnt < 46) begin
                        txd <= 8'h00;
                        pl_cnt <= pl_cnt + 1;
                    end else begin
                        fcs_latch <= ~crc_next;
                        txd <= ~crc_next[7:0];
                        fcs_cnt <= 1;
                        state <= fcs;
                    end
                end
            end
             
             fcs: begin
                tx_valid <= 1;
                if (tx_ready) begin
                    case (fcs_cnt)
                        2'd1: begin 
                            txd <= fcs_latch[15:8]; 
                            fcs_cnt <= 2; 
                        end
                        2'd2: begin 
                            txd <= fcs_latch[23:16]; 
                            fcs_cnt <= 3; 
                        end
                        2'd3: begin 
                            txd <= fcs_latch[31:24]; 
                            fcs_cnt <= 0; 
                        end
                        2'd0: begin tx_valid <= 0; 
                            done <= 1; 
                            state <= idle; 
                        end
                    endcase
                end
            end
        endcase  
    end
end    
endmodule
