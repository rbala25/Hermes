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
    
//localparam [127:0] FRAMES = {
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd23, 2'b10, 16'h0000, //Reg=0x17, Data=0x0000 (force MII mode)
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd0,  2'b10, 16'h8000 //reset
//};
//localparam [255:0] FRAMES = {
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd23, 2'b10, 16'h0000,
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd0,  2'b10, 16'h8000,
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd0, 5'd23, 2'b10, 16'h0000,
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd0, 5'd0,  2'b10, 16'h8000
//};
 
//soft reset to both
//localparam [127:0] FRAMES_P1 = {
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd0, 2'b10, 16'h8000,
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd0, 5'd0, 2'b10, 16'h8000
//};
 
////force MII mode
//localparam [127:0] FRAMES_P2 = {
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd23, 2'b10, 16'h0000,
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd0, 5'd23, 2'b10, 16'h0000
//};
 
////soft reset again to activate MII mode
//localparam [127:0] FRAMES_P3 = {
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd0, 2'b10, 16'h8000,
//    32'hFFFFFFFF, 2'b01, 2'b01, 5'd0, 5'd0, 2'b10, 16'h8000
//};

localparam [63:0] FRAMES = {
    32'hFFFFFFFF, 2'b01, 2'b01, 5'd1, 5'd0, 2'b10, 16'h2100
};
localparam int NBITS = 64;
 
localparam int HALF = 25; //100MHz/50 = 2MHz MDC
//localparam int NBITS = 128;
localparam int WAIT1_CYC = 500000;
localparam int WAIT2_CYC = 1000000; 
localparam int WAIT3_CYC = 500000;
 
typedef enum logic [1:0] {
    WAIT,
    SEND,
    IDLE
} state_t;

state_t state;
logic [19:0] wait_cnt;
logic [5:0] phase;
logic [6:0] bit_cnt;

always_ff @(posedge clk) begin
    if (rst) begin
        state    <= WAIT;
        wait_cnt <= 0;
        phase    <= 0;
        bit_cnt  <= 0;
        mdc      <= 0;
        mdio     <= 1;
        done     <= 0;
    end else begin
        unique case (state)
            WAIT: begin
                wait_cnt <= wait_cnt + 1;
                if (wait_cnt == WAIT_CYC - 1) begin
                    wait_cnt <= 0;
                    state <= SEND;
                    mdio <= FRAMES[NBITS-1];
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
                        mdio <= 1;
                    end else begin
                        bit_cnt <= bit_cnt + 1;
                        mdio <= FRAMES[NBITS - 2 - bit_cnt];
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
 
