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
        curr         <= idle;
        valid        <= 1'b0;
        frame_active <= 1'b0;
        nibble_sel   <= 1'b0;
        lower_nibble <= 4'h0;
    end else begin
        valid        <= 0; //defaults
        frame_active <= 0;

        unique case(curr)
            idle: begin
                nibble_sel <= 0;
                if(rx_dv) curr <= preamble;
            end

            preamble: begin
                if(!rx_dv) begin
                    curr       <= idle;    //rx_dv dropped before SFD
                    nibble_sel <= 0;
                end else if(!nibble_sel) begin //lower nibble - just store it
                    lower_nibble <= rxd;
                    nibble_sel   <= 1;
                end else begin                 //upper nibble - check if this byte is SFD
                    nibble_sel <= 0;
                    if({rxd, lower_nibble} == 8'hD5) begin //{upper, lower} - SFD detected
                        curr         <= active;
                        frame_active <= 1;
                    end //else 0x55 preamble, stay
                end
            end

            active: begin
                if(!rx_dv) begin
                    curr       <= idle;    //frame over
                    nibble_sel <= 0;
                end else if(rx_er) begin
                    curr       <= idle;    //erred out, discard frame
                    nibble_sel <= 0;
                end else if(!nibble_sel) begin //lower nibble
                    lower_nibble <= rxd;
                    nibble_sel   <= 1;
                    frame_active <= 1;
                end else begin                 //upper nibble - emit full byte
                    data         <= {rxd, lower_nibble};
                    valid        <= 1;
                    frame_active <= 1;
                    nibble_sel   <= 0;
                end
            end
        endcase
    end
end
endmodule
