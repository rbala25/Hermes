`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2026 03:40:38 PM
// Design Name: 
// Module Name: ilink_tx_tb
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


module ilink_tx_tb;

localparam CLK_PERIOD = 40;

logic clk = 0, rst;
always #(CLK_PERIOD/2) clk = ~clk;

logic established, neg_response, estab_ack;
logic [255:0] hmac_negotiate, hmac_establish;
logic [63:0] req_timestamp;

logic tx_grant, tx_done;
logic [7:0] payload_in_data;
logic payload_in_valid, payload_in_last, payload_in_ready;

logic quote_valid;
logic [63:0] bid_price, ask_price;
logic [31:0] bid_size, ask_size;

logic [7:0] prev_data;
logic prev_last;

always_ff @(posedge clk) begin
    prev_data <= payload_in_data;
    prev_last <= payload_in_last;
end

logic cancel_bid, cancel_ask;
logic directional_valid, directional_side;
logic [63:0] directional_price;
logic [31:0] directional_size;

logic [63:0] bid_order_id, ask_order_id;

logic start;
logic [7:0] flags;
logic [15:0] tcp_length, payload_csum;
logic ilink_established;

ilink_tx dut (
    .clk(clk),
    .rst(rst),

    .established(established),
    .hmac_negotiate(hmac_negotiate),
    .hmac_establish(hmac_establish),
    .req_timestamp(req_timestamp),

    .neg_response(neg_response),
    .estab_ack(estab_ack),
    .ilink_established(ilink_established),

    .tx_grant(tx_grant),
    .start(start),
    .flags(flags),
    .tcp_length(tcp_length),
    .payload_csum(payload_csum),
    .tx_done(tx_done),

    .payload_in_data(payload_in_data),
    .payload_in_valid(payload_in_valid),
    .payload_in_last(payload_in_last),
    .payload_in_ready(payload_in_ready),

    .quote_valid(quote_valid),
    .bid_price(bid_price),
    .bid_size(bid_size),
    .ask_price(ask_price),
    .ask_size(ask_size),

    .cancel_bid(cancel_bid),
    .cancel_ask(cancel_ask),

    .directional_valid(directional_valid),
    .directional_side(directional_side),
    .directional_price(directional_price),
    .directional_size(directional_size),

    .bid_order_id(bid_order_id),
    .ask_order_id(ask_order_id)
);

always_ff @(posedge clk) begin
    payload_in_ready <= payload_in_valid;
    tx_grant <= established;
    tx_done <= payload_in_valid && payload_in_last;
end

logic [7:0] buff [0:255];
integer count;

function [15:0] rd16(input integer o);
    rd16 = {buff[o+1], buff[o]};
endfunction

function [31:0] rd32(input integer o);
    rd32 = {buff[o+3], buff[o+2], buff[o+1], buff[o]};
endfunction

function [63:0] rd64(input integer o);
    rd64 = {
        buff[o+7], buff[o+6], buff[o+5], buff[o+4],
        buff[o+3], buff[o+2], buff[o+1], buff[o]
    };
endfunction

task capture;
    integer i;
    begin
        i = 0;

        while (!payload_in_valid)
            @(posedge clk);

        while (1) begin
            @(posedge clk);

            if (payload_in_valid) begin
                buff[i] = prev_data;
                i = i + 1;

                if (prev_last)
                    break;
            end
        end

        count = i;
    end
endtask

initial begin
    rst = 1;
    established = 0;
    neg_response = 0;
    estab_ack = 0;

    quote_valid = 0;
    cancel_bid = 0;
    cancel_ask = 0;
    directional_valid = 0;

    hmac_negotiate = 256'h1234;
    hmac_establish = 256'h5678;
    req_timestamp = 64'h1;

    repeat (5) @(posedge clk);
    rst = 0;

    $display("TEST: Negotiate");

    established = 1;

    capture();

    $display("len=%0d template=%0d",
        count,
        rd16(6)
    );

    $display("TEST: Establish");

    @(posedge clk);
    neg_response = 1;
    @(posedge clk);
    neg_response = 0;

    capture();

    $display("len=%0d template=%0d nextSeq=%0d",
        count,
        rd16(6),
        rd32(130)
    );


    estab_ack = 1;
    @(posedge clk);
    estab_ack = 0;

    $display("TEST: NewOrderSingle");

    bid_price = 64'd4_999_500_000_000;
    bid_size  = 5;

    ask_price = 64'd5_000_500_000_000;
    ask_size  = 5;

    quote_valid = 1;
    @(posedge clk);
    quote_valid = 0;

    capture();

    $display("template=%0d price=%0d seq=%0d side=%0d",
        rd16(6),
        rd64(12),
        rd32(29),
        buff[28]
    );

    $display("TEST: Cancel");

    bid_order_id = 64'h1234;

    cancel_bid = 1;
    @(posedge clk);
    cancel_bid = 0;

    capture();

    $display("template=%0d orderID=%h seq=%0d",
        rd16(6),
        rd64(12),
        rd32(29)
    );


    $display("done");
    $finish;
end

initial begin
    #5_000_000;
    $display("timeout");
    $finish;
end


endmodule
