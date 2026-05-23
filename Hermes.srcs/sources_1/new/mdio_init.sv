`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/22/2026 10:16:12 PM
// Design Name: 
// Module Name: mdio_init
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


module mdio_init(
    input logic clk, //100 MHz
    input logic rst, 
    output logic mdc, //when to read
    output logic mdio,
    output logic done
    );
    
localparam [63:0] FRAME = {32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd0, 2'b10, 16'h8000};
localparam int HALF = 25; //100MHz/50 = 2MHz MDC
localparam int NBITS = 64;
localparam int WAIT_CYC = 100000; //1ms startup delay
 
typedef enum logic [1:0] {
    WAIT,
    SEND,
    IDLE
} state_t;
 
state_t state;
logic [16:0] wait_cnt;
logic [5:0] phase;
logic [6:0] bit_cnt;
 
always_ff @(posedge clk) begin
    if (rst) begin
        state <= WAIT;
        wait_cnt <= 0;
        phase <= 0;
        bit_cnt <= 0;
        mdc <= 0;
        mdio <= 1;
        done <= 0;
    end else begin
        unique case (state)
            WAIT: begin
                wait_cnt <= wait_cnt + 1;
                if (wait_cnt == WAIT_CYC - 1) begin
                    state <= SEND;
                    mdio <= FRAME[NBITS-1]; //preload
                end
            end
 
            SEND: begin
                if (phase < 2*HALF - 1) begin
                    phase <= phase + 1;
                    if (phase == HALF - 1) mdc <= 1;
                end else begin
                    phase <= 0;
                    mdc <= 0;
                    if (bit_cnt == NBITS - 1) begin
                        state <= IDLE;
                        mdio <= 1; //release
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                        mdio <= FRAME[NBITS - 2 - bit_cnt];
                    end
                end
            end
 
            IDLE: begin
                done <= 1;
            end
        endcase
    end
end
 
endmodule
