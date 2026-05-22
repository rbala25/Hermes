`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/18/2026 01:18:13 PM
// Design Name: 
// Module Name: mii_rx
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


module mii_rx(output logic [7:0] data, output logic valid, output logic frame_active,
              input logic rxclk, input logic [3:0] rxd, input logic rx_dv, input logic rx_er, input logic rst);

//no DDR, rising edge only
//lower nibble first, upper nibble second
logic [3:0] lower_nibble;
logic nibble_sel; //0=waiting for lower, 1=waiting for upper

//preamble is 0x55, SFD is 0xD5
typedef enum logic [1:0] {
    idle, preamble, active
} state_t;
state_t curr;

always_ff @(posedge rxclk) begin
    if(rst) begin
        curr <= idle;
        valid <= 1'b0;
        frame_active <= 1'b0;
        nibble_sel <= 1'b0;
        lower_nibble <= 4'h0;
    end else begin
        valid <= 0; //defaults
        if (rx_dv) $display("MII_RX: clk tick, curr=%0d rx_dv=%0d t=%0t", curr, rx_dv, $time);  
        
        unique case(curr)
            idle: begin
                frame_active <= 0;
                nibble_sel <= 0;
                if(rx_dv) curr <= preamble;
            end

            preamble: begin
                frame_active <= 0;
                if(!rx_dv) begin
                    curr <= idle;
                    nibble_sel <= 0;
                end else if(!nibble_sel) begin //lower nibble
                    lower_nibble <= rxd;
                    nibble_sel <= 1;
                end else begin                 //upper nibble
                    nibble_sel <= 0;
                    if({rxd, lower_nibble} == 8'hD5) begin //SFD
                        curr <= active;
                        frame_active <= 1;
                    end 
                end
            end

            active: begin
                if(!rx_dv) begin
                    curr <= idle;    //frame over
                    nibble_sel <= 0;
                    frame_active <= 0;
                end else if(rx_er) begin
                    curr <= idle;    //erred out
                    nibble_sel <= 0;
                    frame_active <= 0;
                end else if(!nibble_sel) begin //lower nibble
                    lower_nibble <= rxd;
                    nibble_sel <= 1;
                    frame_active <= 1;
                end else begin
                    data <= {rxd, lower_nibble};
                    valid <= 1;
                    frame_active <= 1;
                    nibble_sel <= 0;
                    $display("MII_RX: byte=%02X t=%0t", {rxd,lower_nibble}, $time);
                end
            end
        endcase
    end
end
endmodule
