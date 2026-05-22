`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 01:26:20 AM
// Design Name: 
// Module Name: mii_tx
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


module mii_tx(
    input  logic tx_clk,
    input  logic rst,
    input  logic [7:0] data,
    input  logic valid,
    
    output logic ready,
    output logic [3:0] txd,
    output logic tx_en
    );
    
typedef enum logic [1:0] {
    idle, preamble, transmit
} state_t;
 
state_t state;
logic [3:0] cnt;
logic nibble_sel;
logic [7:0] byte_buf;

always_ff @(posedge tx_clk) begin
    if(rst) begin
//        $display("MII_TX: RESET at t=%0t", $time); //bro wtf
        state <= idle;
        cnt <= 0;
        nibble_sel <= 0;
        byte_buf <= 0;
        txd <= 0;
        tx_en <= 0;
        ready <= 0;
    end else begin
        tx_en <= 0;
        ready <= 0;
        txd <= 4'h0;
        
        unique case (state)
            idle: begin
                nibble_sel <= 0;
                cnt <= 0;
                if(valid) begin
//                    $display("MII_TX: starting, valid=%0d t=%0t", valid, $time);
                    state <= preamble;
                end
            end
            
            preamble: begin //7 bytes 0x55, then 0xD5 (lower nibble (5) first)
                tx_en <= 1;
                cnt <= cnt + 1;
//                $display("MII_TX: preamble cnt=%0d valid=%0d t=%0t", cnt, valid, $time);
                if(cnt == 15)begin
                    txd <= 4'hd;
                    byte_buf <= data;
                    ready <= 1;
                    state <= transmit;
                    cnt <= 0;
                end else txd <= 4'h5;
            end
            
            transmit: begin
                tx_en <= 1;
                if(!nibble_sel) begin
                    txd <= byte_buf[3:0];
                    nibble_sel <= ~nibble_sel;
                end else begin
                    txd <= byte_buf[7:4];
                    nibble_sel <= ~nibble_sel;
                    ready <= 1;
                    if(valid) byte_buf <= data;
                    else begin 
//                        $display("MII_TX: valid dropped in transmit t=%0t", $time);
                         state <= idle; 
                     end
                end
            end
        endcase
    end
end
endmodule
