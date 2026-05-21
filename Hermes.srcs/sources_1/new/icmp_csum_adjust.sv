`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 03:12:55 PM
// Design Name: 
// Module Name: icmp_csum_adjust
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: For ping return
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module icmp_csum_adjust(
    input  logic [15:0] csum_in,
    output logic [15:0] csum_out 
    );
    
    logic [16:0] sum;
//    always_comb begin
//        sum     = {1'b0, ~csum_in} + 17'h0F7FF;
//        if (sum[16])
//            sum = {1'b0, sum[15:0]} + 17'h1;
//        csum_out = ~sum[15:0];
//    end
    
    //RFC 1624: HC' = ~(~HC + ~m + m'), m=0x0800 m'=0x0000 so ~m=0xF7FF m'=no-op
    assign sum     = {1'b0, ~csum_in} + 17'h0F7FF;
    assign csum_out = ~(sum[16] ? sum[15:0] + 16'h1 : sum[15:0]);
    
endmodule
