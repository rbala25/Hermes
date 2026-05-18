`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:47:23 PM
// Design Name: 
// Module Name: eth_parser_tb
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


module eth_parser_tb;

logic clk = 0;
logic rst;
logic [47:0] dest_mac, src_mac;
logic [15:0] ether_type;
logic header_valid;
logic [7:0] payload_data;
logic payload_valid;
logic frame_done;
logic  error;
logic [7:0] data;
logic valid;
logic frame_active;

eth_parser dut (.dest_mac(dest_mac), .src_mac(src_mac), .ether_type(ether_type), .header_valid(header_valid), .payload_data(payload_data),
    .payload_valid(payload_valid), .frame_done(frame_done), .error(error), .clk(clk), .rst(rst), .data(data), .valid(valid), .frame_active(frame_active));

always #20 clk = ~clk;

logic [7:0] rx_payload[$]; //$ makes it a dynamic array 
always_ff @(posedge clk)
    if (payload_valid) rx_payload.push_back(payload_data);
    
task automatic send_byte(input logic [7:0] b);
    @(posedge clk); #1;
    data         = b;
    valid        = 1;
    frame_active = 1;
    @(posedge clk); #1;
    valid        = 0;
endtask

endmodule
