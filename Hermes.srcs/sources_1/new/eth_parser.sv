`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: eth_parser
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


module eth_parser(output logic [47:0] dest_mac, output logic [47:0] src_mac, output logic [15:0] ether_type, output logic header_valid,
                    output logic [7:0] payload_data, output logic payload_valid, output logic frame_done, output logic error,
                    input logic clk, input logic rst, input logic [7:0] data, input logic valid, input logic frame_active);
                    
    typedef enum logic [2:0] {
        idle,
        destmac,
        srcmac,
        ether,
        payload
    } state_t
                    
endmodule
