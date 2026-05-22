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
            
            if(frame_active_prev && !frame_active) begin //non blocking operators (delayed until next pos edge)
                state <= idle;
                cnt <= 0;
                fcs_count <= 0;
                
                if(state == payload) begin
                    frame_done <= 1; //good end, ignore FCS. FCS is already checked by the PHY
                end else begin
                    error <= 1; //bad
                end
            end
            
            else if (valid) begin
                unique case (state) 
                    idle: begin
                        dest_mac <= {40'h0, data};
                        cnt <= cnt+1;
                        state <= destmac;
                    end
                    
                    destmac: begin
                        dest_mac <= {dest_mac[39:0], data};
                        cnt <= cnt+1;
                        if(cnt >= 5) begin
                            cnt <= 0;
                            state <= srcmac;
                        end
                    end
                    
                    srcmac: begin
                        src_mac <= {src_mac[39:0], data};
                        cnt <= cnt+1;
                        if(cnt >= 5) begin
                            cnt <= 0;
                            state <= ether;
                        end
                    end
                    
                    ether: begin //2 bytes
                        ether_type <= {ether_type[7:0], data};
                        cnt <= cnt + 1;
                        
                        if(cnt >= 1) begin
                            cnt <= 0;
                            state <= payload;
                            header_valid <= 1;
                            fcs_count <= 0;
//                            $display("ETH: header_valid, ether_type=%04X t=%0t", {ether_type[7:0],data}, $time);
                        end
                    end
                    
                    payload: begin
                        if(fcs_count < 4) begin
                            fcs_buf[fcs_count] <= data;
                            fcs_count <= fcs_count + 1;
                        end else begin
                            payload_data <= fcs_buf[0];
                            payload_valid <= 1;
//                            $display("ETH: payload_valid, data=%02X t=%0t", fcs_buf[0], $time);
                            
                            fcs_buf[0] <= fcs_buf[1];
                            fcs_buf[1] <= fcs_buf[2];
                            fcs_buf[2] <= fcs_buf[3];
                            fcs_buf[3] <= data;
                        end
                    end
                endcase
            end
        end
    end          
endmodule
