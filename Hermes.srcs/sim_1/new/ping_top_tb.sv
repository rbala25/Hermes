`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/21/2026 05:29:13 PM
// Design Name: 
// Module Name: ping_top_tb
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


module ping_top_tb;


logic tx_clk = 0;
logic rx_clk = 0;
always #20 tx_clk = ~tx_clk;
always #20 rx_clk = ~rx_clk;

logic rstb;
logic [3:0] txd;
logic tx_en;
logic [3:0] rxd;
logic rx_dv;

ping_top #(.IP(32'hC0A80164)) dut (
    .tx_clk(tx_clk),
    .rx_clk(rx_clk),
    .rstb(rstb),
    .txd(txd),
    .tx_en(tx_en),
    .rxd(rxd),
    .rx_dv(rx_dv)
);


logic [7:0] rx_captured [0:511];
int rx_cap_len = 0;
logic [3:0] nibble_buf;
logic nibble_phase = 0; //0 = waiting for low nibble, 1 = waiting for high

always @(posedge tx_clk) begin
    if (tx_en) begin
        if (!nibble_phase) begin
            nibble_buf   <= txd;
            nibble_phase <= 1;
        end else begin
            rx_captured[rx_cap_len] <= {txd, nibble_buf};
            rx_cap_len              <= rx_cap_len + 1;
            nibble_phase            <= 0;
        end
    end else begin
        nibble_phase <= 0;
    end
end

//mii tx
task automatic send_nibble(input logic [3:0] n);
    @(negedge rx_clk);
    rxd  = n;
    rx_dv = 1;
endtask

task automatic send_byte(input logic [7:0] b);
    send_nibble(b[3:0]);
    send_nibble(b[7:4]);
endtask

task automatic send_preamble;
    repeat(7) send_byte(8'h55);
    send_byte(8'hD5);
endtask

task automatic end_frame;
    @(negedge rx_clk);
    rx_dv = 0;
    rxd   = 0;
endtask

//eth: dst=ff:ff:ff:ff:ff:ff src=aa:bb:cc:dd:ee:ff type=0x0800
//ip:  src=192.168.1.1 dst=192.168.1.100 proto=1 ttl=64 id=0x0001 total_len=32
//icmp: type=8 code=0 id=0x1234 seq=0x0005
//payload: DE AD BE EF
//checksums left as 0x0000
localparam int FRAME_LEN = 42;
localparam int PAYLOAD_LEN = 4;
localparam int FCS_LEN = 4;
logic [7:0] frame [0:FRAME_LEN-1];
logic [7:0] icmp_payload [0:PAYLOAD_LEN-1];
logic [7:0] fcs [0:FCS_LEN-1];

task automatic build_frame;
    // ethernet
    frame[0]=8'hFF; frame[1]=8'hFF; frame[2]=8'hFF;
    frame[3]=8'hFF; frame[4]=8'hFF; frame[5]=8'hFF;
    frame[6]=8'hAA; frame[7]=8'hBB; frame[8]=8'hCC;
    frame[9]=8'hDD; frame[10]=8'hEE; frame[11]=8'hFF;
    frame[12]=8'h08; frame[13]=8'h00;
    // ip
    frame[14]=8'h45; frame[15]=8'h00;
    frame[16]=8'h00; frame[17]=8'h20; //total len 32
    frame[18]=8'h00; frame[19]=8'h01; //id
    frame[20]=8'h00; frame[21]=8'h00;
    frame[22]=8'h40; frame[23]=8'h01; //ttl=64 proto=ICMP
    frame[24]=8'h00; frame[25]=8'h00; //ip checksum (placeholder)
    frame[26]=8'hC0; frame[27]=8'hA8; frame[28]=8'h01; frame[29]=8'h01; // src 192.168.1.1
    frame[30]=8'hC0; frame[31]=8'hA8; frame[32]=8'h01; frame[33]=8'h64; // dst 192.168.1.100

    frame[34]=8'h08; frame[35]=8'h00; // type=8 code=0
    frame[36]=8'h00; frame[37]=8'h00; // icmp checksum (placeholder)
    frame[38]=8'h12; frame[39]=8'h34; // identifier
    frame[40]=8'h00; frame[41]=8'h05; // seq=5

    icmp_payload[0]=8'hDE; icmp_payload[1]=8'hAD;
    icmp_payload[2]=8'hBE; icmp_payload[3]=8'hEF;
    
    
    fcs[0]=8'h00; fcs[1]=8'h00; fcs[2]=8'h00; fcs[3]=8'h00; //dummy fcs
endtask

task automatic send_ping;
    send_preamble();
    foreach(frame[i]) send_byte(frame[i]);
    foreach(icmp_payload[i]) send_byte(icmp_payload[i]);
    foreach(fcs[i]) send_byte(fcs[i]);        
    end_frame();
endtask

//reply checking
localparam int PREAMBLE_BYTES = 8; 

task automatic check_reply;
 
    for (int i = 0; i < 7; i++) begin
        if (rx_captured[i] !== 8'h55)
            $display("FAIL: preamble byte %0d = 0x%02X, expected 0x55", i, rx_captured[i]);
    end
    if (rx_captured[7] !== 8'hD5)
        $display("FAIL: SFD = 0x%02X, expected 0xD5", rx_captured[7]);

    //ethernet dst mac should be aa:bb:cc:dd:ee:ff 
    if (rx_captured[PREAMBLE_BYTES+0] !== 8'hAA ||
        rx_captured[PREAMBLE_BYTES+1] !== 8'hBB ||
        rx_captured[PREAMBLE_BYTES+2] !== 8'hCC ||
        rx_captured[PREAMBLE_BYTES+3] !== 8'hDD ||
        rx_captured[PREAMBLE_BYTES+4] !== 8'hEE ||
        rx_captured[PREAMBLE_BYTES+5] !== 8'hFF)
        $display("FAIL: dst MAC mismatch");
    else
        $display("PASS: dst MAC correct");


    if ({rx_captured[PREAMBLE_BYTES+12], rx_captured[PREAMBLE_BYTES+13]} !== 16'h0800)
        $display("FAIL: ethertype = 0x%04X", {rx_captured[PREAMBLE_BYTES+12], rx_captured[PREAMBLE_BYTES+13]});
    else
        $display("PASS: ethertype correct");

    // ip src should be 192.168.1.100)
    if ({rx_captured[PREAMBLE_BYTES+26], rx_captured[PREAMBLE_BYTES+27],
         rx_captured[PREAMBLE_BYTES+28], rx_captured[PREAMBLE_BYTES+29]} !== 32'hC0A80164)
        $display("FAIL: IP src = %0d.%0d.%0d.%0d",
            rx_captured[PREAMBLE_BYTES+26], rx_captured[PREAMBLE_BYTES+27],
            rx_captured[PREAMBLE_BYTES+28], rx_captured[PREAMBLE_BYTES+29]);
    else
        $display("PASS: IP src correct (192.168.1.100)");

    // ip dst should be 192.168.1.1 
    if ({rx_captured[PREAMBLE_BYTES+30], rx_captured[PREAMBLE_BYTES+31],
         rx_captured[PREAMBLE_BYTES+32], rx_captured[PREAMBLE_BYTES+33]} !== 32'hC0A80101)
        $display("FAIL: IP dst = %0d.%0d.%0d.%0d",
            rx_captured[PREAMBLE_BYTES+30], rx_captured[PREAMBLE_BYTES+31],
            rx_captured[PREAMBLE_BYTES+32], rx_captured[PREAMBLE_BYTES+33]);
    else
        $display("PASS: IP dst correct (192.168.1.1)");

    //icmp type should be 0 (echo reply)
    if (rx_captured[PREAMBLE_BYTES+34] !== 8'h00)
        $display("FAIL: ICMP type = 0x%02X, expected 0x00", rx_captured[PREAMBLE_BYTES+34]);
    else
        $display("PASS: ICMP type = 0 (echo reply)");

    //icmp code should be 0
    if (rx_captured[PREAMBLE_BYTES+35] !== 8'h00)
        $display("FAIL: ICMP code = 0x%02X, expected 0x00", rx_captured[PREAMBLE_BYTES+35]);
    else
        $display("PASS: ICMP code correct");

    if ({rx_captured[PREAMBLE_BYTES+38], rx_captured[PREAMBLE_BYTES+39]} !== 16'h1234)
        $display("FAIL: identifier = 0x%04X, expected 0x1234",
            {rx_captured[PREAMBLE_BYTES+38], rx_captured[PREAMBLE_BYTES+39]});
    else
        $display("PASS: identifier echoed correctly");

    if ({rx_captured[PREAMBLE_BYTES+40], rx_captured[PREAMBLE_BYTES+41]} !== 16'h0005)
        $display("FAIL: seq = 0x%04X, expected 0x0005",
            {rx_captured[PREAMBLE_BYTES+40], rx_captured[PREAMBLE_BYTES+41]});
    else
        $display("PASS: seq echoed correctly");

    // payload should be DE AD BE EF
    if (rx_captured[PREAMBLE_BYTES+42] !== 8'hDE ||
        rx_captured[PREAMBLE_BYTES+43] !== 8'hAD ||
        rx_captured[PREAMBLE_BYTES+44] !== 8'hBE ||
        rx_captured[PREAMBLE_BYTES+45] !== 8'hEF)
        $display("FAIL: payload mismatch: %02X %02X %02X %02X",
            rx_captured[PREAMBLE_BYTES+42], rx_captured[PREAMBLE_BYTES+43],
            rx_captured[PREAMBLE_BYTES+44], rx_captured[PREAMBLE_BYTES+45]);
    else
        $display("PASS: payload echoed correctly");
endtask


initial begin
    rxd   = 0;
    rx_dv = 0;
    rstb  = 0;
    repeat(10) @(posedge rx_clk);
    rstb = 1;
    repeat(5) @(posedge rx_clk);

    build_frame();
    send_ping();

    //wait for tx_en to go high then go low (frame complete)
    @(posedge tx_en);
    $display("INFO: TX started at %0t", $time);
    @(negedge tx_en);
    $display("INFO: TX done at %0t, captured %0d bytes", $time, rx_cap_len);

    repeat(5) @(posedge tx_clk); // let capture settle
    check_reply();

    $display("INFO: all checks done");
    $finish;
end

initial begin
    #2000000;
    $display("FAIL: timeout");
    $finish;
end

endmodule
