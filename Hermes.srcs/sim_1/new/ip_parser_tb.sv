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

initial begin
    rst = 1;
    payload = 0;
    payload_valid = 0;
    header_valid = 0;
    ether = 0;
    frame_done = 0;
    error = 0;
 
    repeat(4) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);
 
    //test 1 - valid ipv4 frame, check all fields
    $display("\nTEST 1: valid ipv4 frame");
    start_frame(16'h0800);
    send_header(VALID_HDR);
 
    check("ip_header_valid", ip_header_valid == 1);
    check("ip_version == 4", ip_version == 4'h4);
    check("ip_ihl == 5", ip_ihl == 4'h5);
    check("ip_total_len == 0x0028", ip_total_len == 16'h0028);
    check("ip_id == 0x1234", ip_id == 16'h1234);
    check("ip_flags == 010 (DF)", ip_flags == 3'b010);
    check("ip_frag_offset == 0", ip_frag_offset == 13'h0);
    check("ip_ttl == 64", ip_ttl == 8'h40);
    check("ip_protocol == 6 (TCP)", ip_protocol == 8'h06);
    check("ip_checksum == 0x5CF2", ip_checksum == 16'h5CF2);
    check("ip_src == 192.168.1.1", ip_src == 32'hC0A80101);
    check("ip_dest == 10.0.0.1", ip_dest == 32'h0A000001);
    check("ip_checksum_val", ip_checksum_val == 1);
    check("ip_is_fragment == 0", ip_is_fragment == 0);
    check("ip_error == 0", ip_error == 0);
 
    send_byte(8'hDE); 
    check("payload 0xDE", ip_payload_valid && ip_payload_data == 8'hDE);
    send_byte(8'hAD); 
    check("payload 0xAD", ip_payload_valid && ip_payload_data == 8'hAD);
    send_byte(8'hBE); 
    check("payload 0xBE", ip_payload_valid && ip_payload_data == 8'hBE);
    send_byte(8'hEF); 
    check("payload 0xEF", ip_payload_valid && ip_payload_data == 8'hEF);
 
    end_frame();
    check("ip_payload_done", ip_payload_done == 1);
 
    repeat(3) @(posedge clk);
 
    //test 2 - non-ipv4 ethertype (ARP), should be ignored entirely
    $display("\nTEST 2: ARP ethertype (0x0806)");
    start_frame(16'h0806);
    send_header(VALID_HDR);
 
    check("ip_header_valid == 0", ip_header_valid  == 0);
    check("ip_payload_valid == 0", ip_payload_valid == 0);
 
    end_frame();
    check("ip_error == 0", ip_error == 0);
 
    repeat(3) @(posedge clk);
 
    //test 3 - bad version
    $display("\nTEST 3: bad IP version (0x65)");
    start_frame(16'h0800);
    send_byte(8'h65); //version=6, ihl=5
    for(int i = 1; i < 20; i++) send_byte(VALID_HDR[i]);
 
    check("ip_header_valid == 0", ip_header_valid == 0);
 
    end_frame();
    check("ip_error on frame_done in DROP", ip_error == 1);
 
    repeat(3) @(posedge clk);
 
    //test 4 - mf=1
    $display("\nTEST 4: fragmented packet");
    start_frame(16'h0800);
    send_header(FRAG_HDR);
 
    check("ip_header_valid",       ip_header_valid == 1);
    check("ip_is_fragment == 1",   ip_is_fragment  == 1);
    check("ip_flags[0] == 1 (MF)", ip_flags[0]     == 1);
    check("ip_protocol == 17 (UDP)", ip_protocol   == 8'h11);
 
    end_frame();
    repeat(3) @(posedge clk);
 
    //tst 5 - error signal
    $display("\nTEST 5: error mid-header");
    start_frame(16'h0800);
    for(int i = 0; i < 8; i++) send_byte(VALID_HDR[i]);
 
    inject_error();
    check("ip_error == 1",        ip_error        == 1);
    check("ip_header_valid == 0", ip_header_valid == 0);
 
    repeat(3) @(posedge clk);
 
    //test 6 - truncated
    $display("\nTEST 6: truncated frame");
    start_frame(16'h0800);
    for(int i = 0; i < 12; i++) send_byte(VALID_HDR[i]); //cut off at byte 12
 
    end_frame();
    check("ip_error == 1 (truncated)", ip_error        == 1);
    check("ip_header_valid == 0",      ip_header_valid == 0);
 
    repeat(3) @(posedge clk);
 
    //back to back frames
    $display("\nTEST 7: back-to-back frames");
    start_frame(16'h0800);
    send_header(VALID_HDR);
    send_byte(8'hAA);
    end_frame();
    check("frame 1 payload_done", ip_payload_done == 1);
 
    start_frame(16'h0800);
    send_header(VALID_HDR);
    check("frame 2 header_valid",  ip_header_valid == 1);
    check("frame 2 checksum_val",  ip_checksum_val == 1);
    check("frame 2 src correct",   ip_src          == 32'hC0A80101);
    send_byte(8'hBB);
    end_frame();
    check("frame 2 payload_done", ip_payload_done == 1);
 
    repeat(5) @(posedge clk);
 
    $display("\n%0d passed, %0d failed", pass_count, fail_count);
    $finish;
end
endmodule
