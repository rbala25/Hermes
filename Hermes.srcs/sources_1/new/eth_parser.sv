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
                    
    typedef enum logic [2:0] { //fsm
        idle,
        destmac,
        srcmac,
        ether,
        payload
    } state_t;
    
    state_t state;
    logic[3:0] cnt;
    
    logic frame_active_prev; //previous value
    
    logic [7:0] fcs_buf [0:3]; //shift register for FCS
    logic [2:0] fcs_count;
    
    always_ff @(posedge clk) begin
        if(rst) begin
            state <= idle;
            cnt <= 0;
            src_mac <= 0;
            dest_mac <= 0;
            ether_type <= 0;
            header_valid <= 0;
            payload_data <= 0;
            payload_valid <= 0;
            frame_done <= 0;
            error <= 0;
            fcs_count <= 0;
            fcs_buf[0] <= 0;
            fcs_buf[1] <= 0;
            fcs_buf[2] <= 0;
            fcs_buf[3] <= 0;
            frame_active_prev <= 0;
        end else begin
            header_valid <= 0;
            payload_valid <= 0;
            frame_done <= 0;
            error <= 0;
            frame_active_prev <= frame_active;
        
        end
    end          
endmodule
