`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 01:11:16 PM
// Design Name: 
// Module Name: ip_tx
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


module ip_tx(
    input logic tx_clk,
    input logic rst,

    input logic [31:0] src_ip,
    input logic [31:0] dst_ip,
    input logic [7:0] protocol, //0x01 ICMP, 0x06 TCP, 0x11 UDP
    input logic [15:0] total_length,  
    input logic [15:0] identification,

    input logic start,
    output logic done,

    //icmp_tx
    input logic [7:0] payload_data,
    input logic payload_valid,
    output logic payload_ready,

    //eth_tx
    output logic [7:0] tx_data,
    output logic tx_valid,
    input logic tx_ready 
    );
    
logic [31:0] csum_raw;
logic [16:0] csum_fold;
logic [15:0] checksum;

//ver=4, ihl=5, dscp/ecn = 0, flags = DF, frag_offset = 0, ttl = 64
assign csum_raw  =  32'h4500 + {16'h0, total_length} + {16'h0, identification} + 32'h4000 + {16'h0, 8'h40, protocol}
                  + {16'h0, src_ip[31:16]} + {16'h0, src_ip[15:0]} + {16'h0, dst_ip[31:16]} + {16'h0, dst_ip[15:0]};
 
assign csum_fold = {1'b0, csum_raw[15:0]} + {1'b0, csum_raw[31:16]};
assign checksum  = ~(csum_fold[15:0] + {15'h0, csum_fold[16]});   

typedef enum logic [1:0] {
    idle, header, data
} state_t;

state_t state;
logic [4:0] cnt;

always_ff @(posedge tx_clk) begin
    if (rst) begin
        state <= idle;
        cnt <= 0;
        tx_data <= 0;
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
                if (start) begin
                    tx_data <= 8'h45;
                    tx_valid <= 1;
                    cnt <= 1;
                    state <= header;
                end
            end
            
            header: begin
                if(tx_ready) begin
                    tx_valid <= 1;
                    cnt <= cnt + 1;
                    
                    unique case (cnt)
                        5'd1: tx_data <= 8'h00; //dscp.ecn
                        5'd2: tx_data <= total_length[15:8];
                        5'd3: tx_data <= total_length[7:0];
                        5'd4: tx_data <= identification[15:8];
                        5'd5: tx_data <= identification[7:0];
                        5'd6: tx_data <= 8'h40; //flag df
                        5'd7: tx_data <= 8'h00;  
                        5'd8: tx_data <= 8'h40; //ttl = 64
                        5'd9: tx_data <= protocol;
                        5'd10: tx_data <= checksum[15:8];
                        5'd11: tx_data <= checksum[7:0];
                        5'd12: tx_data <= src_ip[31:24];
                        5'd13: tx_data <= src_ip[23:16];
                        5'd14: tx_data <= src_ip[15:8];
                        5'd15: tx_data <= src_ip[7:0];
                        5'd16: tx_data <= dst_ip[31:24];
                        5'd17: tx_data <= dst_ip[23:16];
                        5'd18: tx_data <= dst_ip[15:8];
                        5'd19: begin
                            tx_data <= dst_ip[7:0];
                            state   <= data;
                        end
                        default: tx_data <= 8'h00;
                    endcase
                end
            end
            
            data: begin
                if(tx_ready && payload_valid) begin
                    tx_data <= payload_data;
                    tx_valid <= 1;
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
