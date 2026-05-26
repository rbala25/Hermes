`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/26/2026 01:43:47 AM
// Design Name: 
// Module Name: integration_tb
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


module integration_tb;

logic clk = 0;
always #10 clk = ~clk;

logic rst;
logic [7:0] udp_payload;
logic udp_payload_valid, udp_payload_done, udp_header_valid;
logic [15:0] udp_dest;
logic udp_error;

logic [63:0] entry_price; //parser to book
logic [31:0] entry_size;
logic [7:0] entry_price_level, entry_update_action, entry_type;
logic is_snapshot, entry_valid, mdp_done, mdp_error;
logic [31:0] mdp_seq_num;
logic [63:0] mdp_sending_time;
logic mdp_pkt_valid;

logic [63:0] best_bid_price, best_ask_price; //book to mm
logic [31:0] best_bid_size, best_ask_size;
logic book_valid, gap_detected;
logic [3:0] rd_level;
logic rd_side;
logic [63:0] rd_price;
logic [31:0] rd_size;

logic [63:0] bid_price, ask_price; //mm outputs
logic [31:0] bid_size, ask_size;
logic quote_valid, cancel_bid, cancel_ask, risk_breach;

logic [63:0] trade_price;
logic [31:0] trade_size;
logic [1:0] trade_aggressor;
logic trade_valid;
logic directional_valid, directional_side;
logic [63:0] directional_price;
logic [31:0] directional_size;

mdp_parser #(.port(16'd14310), .sec_id(32'd12345)) parser (
    .clk, .rst,
    .udp_payload, .udp_payload_valid, .udp_payload_done,
    .udp_header_valid, .udp_dest, .udp_error,
    .mdp_seq_num, .mdp_sending_time, .mdp_pkt_valid,
    .entry_price, .entry_size, .entry_price_level,
    .entry_update_action, .entry_type, .is_snapshot,
    .entry_valid, .mdp_done, .mdp_error,
    .trade_price, .trade_size, .trade_aggressor, .trade_valid
);

order_book book (
    .clk, .rst,
    .entry_price, .entry_size, .entry_price_level,
    .entry_update_action, .entry_type, .is_snapshot,
    .entry_valid, .mdp_done, .mdp_seq_num, .mdp_pkt_valid,
    .best_bid_price, .best_bid_size, .best_ask_price, .best_ask_size,
    .rd_level, .rd_side, .rd_price, .rd_size,
    .book_valid, .gap_detected
);

mm_core #(
    .HALF_SPREAD(64'd100),
    .MAX_POSITION(32'd100),
    .QUOTE_SIZE(32'd1),
    .MAX_ORDER_RATE(16'd100),
    .LOSS_LIMIT(64'd1_000_000_000_000),
    .VWAP_LEVELS(4'd1),
    .SKEW_PER_CONTRACT(64'd1),
    .REFRESH_TICKS(25'd500),
    .CLK_FREQ(32'd25_000_000),
    .OFI_DECAY_TICKS(32'd100_000),
    .OFI_SCALE(64'd1),
    .OFI_THRESHOLD(32'd1_000)
) mm (
    .clk, .rst,
    .best_bid_price, .best_bid_size, .best_ask_price, .best_ask_size,
    .book_valid, .gap_detected,
    .rd_level, .rd_side, .rd_price, .rd_size,
    .fill_valid(1'b0), .fill_price(64'd0), .fill_size(32'd0), .fill_side(1'b0),
    .trade_price, .trade_size, .trade_aggressor, .trade_valid,
    .bid_price, .bid_size, .ask_price, .ask_size,
    .quote_valid, .cancel_bid, .cancel_ask, .risk_breach,
    .directional_valid, .directional_side, .directional_price, .directional_size
);

localparam int PKT_LEN = 102; //lowkey this is just from mdp_parser_tb
logic [7:0] pkt [0:PKT_LEN-1];

task automatic build_snapshot;
    pkt[0]=8'h01; pkt[1]=8'h00; pkt[2]=8'h00; pkt[3]=8'h00;
    pkt[4]=8'h01; pkt[5]=8'h00; pkt[6]=8'h00; pkt[7]=8'h00;
    pkt[8]=8'h00; pkt[9]=8'h00; pkt[10]=8'h00; pkt[11]=8'h00;

    pkt[12]=8'h5A; pkt[13]=8'h00; 

    pkt[14]=8'h0D; pkt[15]=8'h00;
    pkt[16]=8'h34; pkt[17]=8'h00; //updated for id (52)
    pkt[18]=8'h09; pkt[19]=8'h00;
    pkt[20]=8'h08; pkt[21]=8'h00;

    pkt[22]=8'h00; pkt[23]=8'h00; pkt[24]=8'h00; pkt[25]=8'h00;
    pkt[26]=8'h00; pkt[27]=8'h00; pkt[28]=8'h00; pkt[29]=8'h00;
    pkt[30]=8'h39; pkt[31]=8'h30; pkt[32]=8'h00; pkt[33]=8'h00;
    pkt[34]=8'h00;

    pkt[35]=8'h20; pkt[36]=8'h00;
    pkt[37]=8'h02;

    pkt[38]=8'hE8; pkt[39]=8'h03; pkt[40]=8'h00; pkt[41]=8'h00;
    pkt[42]=8'h00; pkt[43]=8'h00; pkt[44]=8'h00; pkt[45]=8'h00;
    pkt[46]=8'h64; pkt[47]=8'h00; pkt[48]=8'h00; pkt[49]=8'h00;
    pkt[50]=8'h00; pkt[51]=8'h00; pkt[52]=8'h00; pkt[53]=8'h00;
    pkt[54]=8'h01;
    pkt[55]=8'h00; pkt[56]=8'h00; pkt[57]=8'h00; pkt[58]=8'h00;
    pkt[59]=8'h30;
    pkt[60]=8'h00; pkt[61]=8'h00; pkt[62]=8'h00; pkt[63]=8'h00;
    pkt[64]=8'h00; pkt[65]=8'h00; pkt[66]=8'h00; pkt[67]=8'h00;
    pkt[68]=8'h00; pkt[69]=8'h00;

    //entry 2
    pkt[70]=8'hD0; pkt[71]=8'h07; pkt[72]=8'h00; pkt[73]=8'h00;
    pkt[74]=8'h00; pkt[75]=8'h00; pkt[76]=8'h00; pkt[77]=8'h00;
    pkt[78]=8'h64; pkt[79]=8'h00; pkt[80]=8'h00; pkt[81]=8'h00;
    pkt[82]=8'h00; pkt[83]=8'h00; pkt[84]=8'h00; pkt[85]=8'h00;
    pkt[86]=8'h01;
    pkt[87]=8'h00; pkt[88]=8'h00; pkt[89]=8'h00; pkt[90]=8'h00;
    pkt[91]=8'h31;
    pkt[92]=8'h00; pkt[93]=8'h00; pkt[94]=8'h00; pkt[95]=8'h00;
    pkt[96]=8'h00; pkt[97]=8'h00; pkt[98]=8'h00; pkt[99]=8'h00;
    pkt[100]=8'h00; pkt[101]=8'h00;
endtask

task automatic send_pkt;
    @(negedge clk);
    udp_dest = 16'd14310;
    udp_header_valid = 1;
    udp_payload_valid = 0;
    @(negedge clk);
    udp_header_valid = 0;
    for (int i = 0; i < PKT_LEN; i++) begin
        @(negedge clk);
        udp_payload = pkt[i];
        udp_payload_valid = 1;
        udp_payload_done = (i == PKT_LEN - 1);
    end
    @(negedge clk);
    udp_payload_valid = 0;
    udp_payload_done = 0;
endtask

localparam int T48_PKT_LEN = 68;
logic [7:0] t48_pkt [0:T48_PKT_LEN-1];

task automatic build_t48_pkt; //t48
    t48_pkt[0]=8'h02; t48_pkt[1]=8'h00; t48_pkt[2]=8'h00; t48_pkt[3]=8'h00;
    t48_pkt[4]=8'h02; t48_pkt[5]=8'h00; t48_pkt[6]=8'h00; t48_pkt[7]=8'h00;
    t48_pkt[8]=8'h00; t48_pkt[9]=8'h00; t48_pkt[10]=8'h00; t48_pkt[11]=8'h00;
    
    t48_pkt[12]=8'h38; t48_pkt[13]=8'h00; //msg_size=56=0x38
    t48_pkt[14]=8'h0B; t48_pkt[15]=8'h00;
    t48_pkt[16]=8'h30; t48_pkt[17]=8'h00;
    t48_pkt[18]=8'h09; t48_pkt[19]=8'h00;
    t48_pkt[20]=8'h08; t48_pkt[21]=8'h00;

    t48_pkt[22]=8'h00; t48_pkt[23]=8'h00; t48_pkt[24]=8'h00; t48_pkt[25]=8'h00; //root 11 bytes
    t48_pkt[26]=8'h00; t48_pkt[27]=8'h00; t48_pkt[28]=8'h00; t48_pkt[29]=8'h00;
    t48_pkt[30]=8'h00; t48_pkt[31]=8'h00; t48_pkt[32]=8'h00;
    
    t48_pkt[33]=8'h20; t48_pkt[34]=8'h00;
    t48_pkt[35]=8'h01;

    t48_pkt[36]=8'hDC; t48_pkt[37]=8'h05; t48_pkt[38]=8'h00; t48_pkt[39]=8'h00;
    t48_pkt[40]=8'h00; t48_pkt[41]=8'h00; t48_pkt[42]=8'h00; t48_pkt[43]=8'h00;

    t48_pkt[44]=8'h0A; t48_pkt[45]=8'h00; t48_pkt[46]=8'h00; t48_pkt[47]=8'h00;

    t48_pkt[48]=8'h39; t48_pkt[49]=8'h30; t48_pkt[50]=8'h00; t48_pkt[51]=8'h00;

    t48_pkt[52]=8'h00; t48_pkt[53]=8'h00; t48_pkt[54]=8'h00; t48_pkt[55]=8'h00;

    t48_pkt[56]=8'h00; t48_pkt[57]=8'h00; t48_pkt[58]=8'h00; t48_pkt[59]=8'h00;

    t48_pkt[60]=8'h01;

    t48_pkt[61]=8'h00; t48_pkt[62]=8'h00; t48_pkt[63]=8'h00; t48_pkt[64]=8'h00; //skip
    t48_pkt[65]=8'h00; t48_pkt[66]=8'h00; t48_pkt[67]=8'h00;
endtask

task automatic send_t48_pkt;
    @(negedge clk);
    udp_dest = 16'd14310;
    udp_header_valid = 1;
    udp_payload_valid = 0;
    @(negedge clk);
    udp_header_valid = 0;
    for (int i = 0; i < T48_PKT_LEN; i++) begin
        @(negedge clk);
        udp_payload = t48_pkt[i];
        udp_payload_valid = 1;
        udp_payload_done = (i == T48_PKT_LEN - 1);
    end
    @(negedge clk);
    udp_payload_valid = 0;
    udp_payload_done = 0;
endtask

logic quote_seen = 0;
always @(posedge clk) if (quote_valid) quote_seen <= 1;

logic dir_valid_seen = 0;
always @(posedge clk) if (directional_valid) dir_valid_seen <= 1;

initial begin
    rst = 1;
    udp_payload = 0; udp_payload_valid = 0;
    udp_payload_done = 0; udp_header_valid = 0;
    udp_dest = 0; udp_error = 0;
    repeat(5) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    build_snapshot();
    send_pkt();

    wait(book_valid);
    $display("PASS: book_valid");

    wait(quote_seen);
    $display("PASS: quote_valid fired  bid=%0d ask=%0d", bid_price, ask_price);

    if (bid_price == 64'd1400)
        $display("PASS: bid_price=1400");
    else
        $display("FAIL: bid_price=%0d expected 1400", bid_price);

    if (ask_price == 64'd1600)
        $display("PASS: ask_price=1600");
    else
        $display("FAIL: ask_price=%0d expected 1600", ask_price);

    if (bid_price < ask_price)
        $display("PASS: bid < ask");
    else
        $display("FAIL: crossed quotes");

    if (!risk_breach)
        $display("PASS: no risk breach");
    else
        $display("FAIL: unexpected risk breach");

    build_t48_pkt(); //ofi test
    send_t48_pkt();

    @(posedge clk iff quote_valid);

    if (bid_price == 64'd1410)
        $display("PASS: OFI shifted bid up bid=%0d", bid_price);
    else
        $display("FAIL: OFI bid wrong bid=%0d expected 1410", bid_price);

    if (ask_price == 64'd1610)
        $display("PASS: OFI shifted ask up ask=%0d", ask_price);
    else
        $display("FAIL: OFI ask wrong ask=%0d expected 1610", ask_price);

    if (!dir_valid_seen)
        $display("PASS: no directional trigger ofi below threshold");
    else
        $display("FAIL: unexpected directional trigger");

    $display("done");
    $finish;
end

initial begin
    #500000;
    $display("FAIL: timeout");
    $finish;
end

endmodule