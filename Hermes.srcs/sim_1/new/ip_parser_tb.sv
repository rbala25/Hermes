`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/20/2026 01:37:29 PM
// Design Name: 
// Module Name: ip_parser_tb
// Project Name: 
// Target Devices: 
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


module ip_parser_tb();
logic clk; //inputs
logic rst;
logic[7:0] payload;
logic payload_valid;
logic header_valid;
logic[15:0] ether;
logic frame_done;
logic error;
 
logic[3:0] ip_version; //outputs
logic[3:0] ip_ihl;
logic[7:0] ip_dscp;
logic[15:0] ip_total_len;
logic[15:0] ip_id;
logic[2:0] ip_flags;
logic[12:0] ip_frag_offset;
logic[7:0] ip_ttl;
logic[7:0] ip_protocol;
logic[15:0] ip_checksum;
logic[31:0] ip_src;
logic[31:0] ip_dest;
logic ip_header_valid;
logic ip_checksum_val;
logic ip_is_fragment;
logic[7:0] ip_payload_data;
logic ip_payload_valid;
logic ip_payload_done;
logic ip_error;

ip_parser dut(.*);

initial clk = 0;
always #20 clk = ~clk; //25Mhz

int pass_count = 0;
int fail_count = 0;

//valid header: 192.168.1.1 -> 10.0.0.1, TCP, TTL=64
//checksum 0x5CF2
localparam logic[7:0] VALID_HDR[0:19] = '{
    8'h45, 8'h00, //version=4 ihl=5, dscp=0
    8'h00, 8'h28, //total length=40
    8'h12, 8'h34, //id=0x1234
    8'h40, 8'h00, //flags=DF, offset=0
    8'h40, 8'h06, //ttl=64, protocol=TCP(6)
    8'h5C, 8'hF2, //checksum
    8'hC0, 8'hA8, 8'h01, 8'h01, //src: 192.168.1.1
    8'h0A, 8'h00, 8'h00, 8'h01  //dst: 10.0.0.1
};

localparam logic[7:0] FRAG_HDR[0:19] = '{ //fragmented, invalid checksum
    8'h45, 8'h00,
    8'h00, 8'h28,
    8'h12, 8'h34,
    8'h20, 8'h00, //flags=MF
    8'h40, 8'h11, 
    8'h00, 8'h00, 
    8'hC0, 8'hA8, 8'h01, 8'h01,
    8'h0A, 8'h00, 8'h00, 8'h01
};

task automatic send_byte(input logic[7:0] data);
    @(negedge clk);
    payload = data;
    payload_valid = 1;
    @(posedge clk); #1;
    payload_valid = 0;
endtask

task automatic start_frame(input logic[15:0] ethertype);
    @(negedge clk);
    ether = ethertype;
    header_valid = 1;
    @(posedge clk); #1;
    header_valid = 0;
endtask

task automatic end_frame;
    @(negedge clk);
    frame_done = 1;
    @(posedge clk); #1;
    frame_done = 0;
endtask

task automatic inject_error;
    @(negedge clk);
    error = 1;
    @(posedge clk); #1;
    error = 0;
endtask

task automatic send_header(input logic[7:0] hdr[0:19]);
    for(int i = 0; i < 20; i++)
        send_byte(hdr[i]);
endtask
 
task automatic check(input string name, input logic cond);
    if(cond) begin
        $display("  PASS  %s", name);
        pass_count++;
    end else begin
        $display("  FAIL  %s", name);
        fail_count++;
    end
endtask

endmodule
