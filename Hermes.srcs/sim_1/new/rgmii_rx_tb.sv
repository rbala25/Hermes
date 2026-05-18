`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:47:23 PM
// Design Name: 
// Module Name: rgmii_rx_tb
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


module rgmii_rx_tb;
    logic rxclk = 0;
    logic [3:0] rxd = 0;
    logic rx_ctl = 0;
    logic [7:0] data;
    logic valid;
    logic frame_active;
    logic rst = 0;
    
    rgmii_rx dut(.rxclk, .rxd, .rx_ctl, .data, .valid, .frame_active, .rst);
    
    always #4 rxclk = ~rxclk;
    
    task automatic send_byte (input logic [7:0] testdata);
        @(negedge rxclk); #1;
        rxd = testdata[3:0]; //set lower half on falling edge so its stable for rising edge
        
        @(posedge rxclk); #1;
        rxd = testdata[7:4];
    endtask
    
    initial begin
    $dumpfile("rgmii_rx_tb.vcd");
    $dumpvars(0, rgmii_rx_tb);
    
    rx_ctl = 0;
    rxd = 0;
    
    rst = 1;
    repeat(32) @(posedge rxclk); //wait
    rst = 0;
    
    @(negedge rxclk); #1;
    rx_ctl = 1;
    
    repeat(7) send_byte(8'h55); //preamble
    send_byte(8'hD5); //sfd

    //actual frame bytes
    send_byte(8'hAA);
    send_byte(8'hBB);
    send_byte(8'hCC);
    send_byte(8'hDD);
    send_byte(8'hEE);
    send_byte(8'hFF);
    
    //end frame
    @(negedge rxclk); #1; //after last neg edge
    rx_ctl = 0;
    rxd    = 0;
    
    repeat(8) @(posedge rxclk);
    $finish;
    
    end
    
    always @(posedge rxclk) begin
        if(valid) $display("[%0t ns] data = 0x%02X", $time, data);
    end

endmodule
