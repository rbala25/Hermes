`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: rgmii_rx
// Project Name: 
// Target Devices: Arty A7 35t
// Tool Versions: 
// Description: OLDER VERSION - THIS IS NOT USED
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module rgmii_rx(output logic [7:0] data, output logic valid, output logic frame_active, 
                input logic rxclk, input logic[3:0] rxd, input logic rx_ctl, input logic rst);
                
//need to capture on both edges - use IDDR
logic [3:0] rxd_rise, rxd_fall;
logic ctl_rise, ctl_fall;

genvar i;
generate
    for(i=0; i<4; i++) begin : ddr_data
        IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .INIT_Q1(0), .INIT_Q2(0))
        iddr_rx (.C(rxclk), .CE(1), .D(rxd[i]), .Q1(rxd_rise[i]), .Q2(rxd_fall[i]), .R(0), .S(0));
    end
endgenerate

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED"), .INIT_Q1(0), .INIT_Q2(0))
iddr_ctl (.C(rxclk), .CE(1'b1), .D(rx_ctl), .Q1(ctl_rise), .Q2(ctl_fall), .R(0), .S(0)); //rx_ctl is also DDR
//rx_dv rising edge - high when data valid
//rx_er falling edge - XOR with rx_dv -> if high, error

logic [7:0] rawdata;
logic rawvalid;
//cant put it directly bc we have to make sure valid and no errors

always_ff @(posedge rxclk) begin
    rawdata <= {rxd_fall, rxd_rise};
    rawvalid <= ctl_rise;
end

logic rx_er;
// assign rx_er = ctl_rise ^ ctl_fall;
always_ff @(posedge rxclk) rx_er <= ctl_rise ^ ctl_fall; //combinational would be 1 cycle ahead

//state machine:
//preamble: 0x55?? check*
//idle: waiting for frame
//active: real data
typedef enum logic [1:0] {
    idle, preamble, active
} state_t;

state_t curr;

always_ff @(posedge rxclk) begin
    if(rst) begin
        curr         <= idle;
        valid        <= 1'b0;
        frame_active <= 1'b0;
    end else begin
        valid <= 0;
        frame_active <= 0; //defaults
        
        unique case(curr)
            idle: begin
                if(rawvalid && rawdata == 8'h55) curr <= preamble;
            end
            
            preamble: begin
                if(!rawvalid) curr <= idle; //never got to SFD (0xD5)
                else if(rawdata == 8'hD5) begin
                    curr <= active;
                    frame_active <= 1;
                end //still 0x55 so still preamble
            end
            
            active: begin
                if(!rawvalid) curr <= idle; //frame over? i think *check
                else if(rx_er) begin
                    curr <= idle; //erred out
                    valid <= 0;
                end else begin
                    data <= rawdata;
                    valid <= 1;
                    frame_active <= 1;
                end       
            end
        endcase    
    end
end
endmodule
