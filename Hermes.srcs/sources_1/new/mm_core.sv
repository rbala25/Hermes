`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/25/2026 05:20:06 PM
// Design Name: 
// Module Name: mm_core
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


module mm_core #(
    parameter logic [63:0] HALF_SPREAD = 64'd5_000_000_000, // $5.00 price9
    parameter logic [31:0] MAX_POSITION = 32'd10, //# contracts
    parameter logic [31:0] QUOTE_SIZE = 32'd1,
    parameter logic [15:0] MAX_ORDER_RATE = 16'd10,
    parameter logic [63:0] LOSS_LIMIT = 64'd1_000_000_000_000, //$1000
    parameter logic [3:0] VWAP_LEVELS = 4'd3, 
    parameter logic [63:0] SKEW_PER_CONTRACT = 64'd1_000_000_000, //$1.00 per contract
    parameter logic [24:0] REFRESH_TICKS = 25'd1_000_000, //40 ms prevent stale quotes
    parameter logic [31:0] CLK_FREQ = 32'd25_000_000
)(
    input logic clk,
    input logic rst,

    input logic [63:0] best_bid_price,
    input logic [31:0] best_bid_size,
    input logic [63:0] best_ask_price,
    input logic [31:0] best_ask_size,
    input logic book_valid,
    input logic gap_detected,

    output logic [3:0] rd_level, //combinational
    output logic rd_side,
    input logic [63:0] rd_price,
    input logic [31:0] rd_size,

    input logic fill_valid,
    input logic [63:0] fill_price,
    input logic [31:0] fill_size,
    input logic fill_side, // 0 = buy fill, 1 = sell fill

    output logic [63:0] bid_price,
    output logic [31:0] bid_size,
    output logic [63:0] ask_price,
    output logic [31:0] ask_size,
    output logic quote_valid, //pulse means new quotes on bid_price/ask_price

    output logic cancel_bid, //pulse based
    output logic cancel_ask,

    output logic risk_breach
);

typedef enum logic [2:0] {
    idle,
    vwap_read,
    div_init,
    div_run,
    mid_calc,
    quote_calc,
    risk,
    emit
} state_t;

state_t state;

logic [127:0] sum_bid_weighted; //vwap
logic [63:0] sum_bid_size;
logic [127:0] sum_ask_weighted;
logic [63:0] sum_ask_size;
logic [4:0] vwap_cnt;

logic [64:0] div_P; // partial remainder
logic [63:0] div_A_lo;
logic [63:0] div_D;
logic [63:0] div_Q; //quotient
logic [5:0] div_cnt;
logic div_phase; //0 = bid, 1 = ask

logic [64:0] P_trial;
logic Q_bit;
assign P_trial = {div_P[63:0], div_A_lo[63]};
assign Q_bit = (P_trial >= {1'b0, div_D}) ? 1'b1 : 1'b0;

logic [63:0] bid_vwap;
logic [63:0] ask_vwap;
logic [63:0] mid_price; //computed prices

logic signed [31:0] net_position; //positive = long, neg = short (signed)
logic signed [127:0] daily_pnl;

logic [24:0] sec_counter; //goes to clk_freq - 1, resets order_count
logic [15:0] order_count;

logic [63:0] prev_best_bid;
logic [63:0] prev_best_ask;
logic fill_requote; //sticky
logic refresh_pending;
logic [24:0] refresh_counter; //using REFRESH_TICKS

logic signed [96:0] skew_product;
assign skew_product = $signed(net_position) * $signed({1'b0, SKEW_PER_CONTRACT}); //comb

logic signed [64:0] bid_q_raw;
logic signed [64:0] ask_q_raw;
assign bid_q_raw = $signed({1'b0, mid_price}) - $signed({1'b0, HALF_SPREAD}) - $signed(skew_product[64:0]); //signed
assign ask_q_raw = $signed({1'b0, mid_price}) + $signed({1'b0, HALF_SPREAD}) - $signed(skew_product[64:0]);

always_ff @(posedge clk) begin
    if (rst) begin
        state <= idle;
        rd_level <= '0;
        rd_side <= 0;
        vwap_cnt <= '0;
        sum_bid_weighted <= '0;
        sum_bid_size <= '0;
        sum_ask_weighted <= '0;
        sum_ask_size <= '0;
        div_P <= '0;
        div_A_lo <= '0;
        div_D <= '0;
        div_Q <= '0;
        div_cnt <= '0;
        div_phase <= 0;
        bid_vwap <= '0;
        ask_vwap <= '0;
        mid_price <= '0;
        net_position <= '0;
        daily_pnl <= '0;
        sec_counter <= '0;
        order_count <= '0;
        refresh_counter <= '0;
        prev_best_bid <= '0;
        prev_best_ask <= '0;
        fill_requote <= 0;
        refresh_pending <= 0;
        bid_price <= '0;
        bid_size <= '0;
        ask_price <= '0;
        ask_size <= '0;
        quote_valid <= 0;
        cancel_bid <= 0;
        cancel_ask <= 0;
        risk_breach <= 0;
    end else begin
        quote_valid <= 0; //defalts
        cancel_bid <= 0;
        cancel_ask <= 0;
    
        if (sec_counter == CLK_FREQ[24:0] - 25'd1) begin
            sec_counter <= 0;
            order_count <= 0;
        end else begin
            sec_counter <= sec_counter + 25'd1;
        end
        
        if (refresh_counter == REFRESH_TICKS - 25'd1) begin
            refresh_counter <= '0;
            refresh_pending <= 1;
        end else begin
            refresh_counter <= refresh_counter + 25'd1;
        end
        
        if (fill_valid) begin
            if (fill_side == 0)
                net_position <= net_position + $signed({1'b0, fill_size});
            else
                net_position <= net_position - $signed({1'b0, fill_size});

            if (fill_side == 0)
                daily_pnl <= daily_pnl
                    + ($signed({1'b0, mid_price}) - $signed({1'b0, fill_price}))
                    * $signed({1'b0, fill_size});
            else
                daily_pnl <= daily_pnl
                    + ($signed({1'b0, fill_price}) - $signed({1'b0, mid_price}))
                    * $signed({1'b0, fill_size});

            fill_requote <= 1;
        end
        
         if (gap_detected) begin
            cancel_bid <= 1;
            cancel_ask <= 1;
        end
        
        case (state)

            idle: begin
                if (book_valid && !gap_detected) begin
                    if (best_bid_price != prev_best_bid || best_ask_price != prev_best_ask || fill_requote || refresh_pending) begin //only catches best bid/ask changes
                        sum_bid_weighted <= 0;
                        sum_bid_size <= 0;
                        sum_ask_weighted <= 0;
                        sum_ask_size <= 0;
                        vwap_cnt <= 0;
                        prev_best_bid <= best_bid_price;
                        prev_best_ask <= best_ask_price;
                        fill_requote <= 0;
                        refresh_pending <= 0;
                        rd_level <= 0;
                        rd_side <= 0;
                        state <= vwap_read;
                    end
                end
            end

            vwap_read: begin
                if (vwap_cnt < {1'b0, VWAP_LEVELS}) begin
                    sum_bid_weighted <= sum_bid_weighted + 128'(rd_price) * 128'(rd_size);
                    sum_bid_size <= sum_bid_size + {32'h0, rd_size};
                end else begin
                    sum_ask_weighted <= sum_ask_weighted + 128'(rd_price) * 128'(rd_size);
                    sum_ask_size <= sum_ask_size + {32'h0, rd_size};
                end

                if (vwap_cnt == (5'(VWAP_LEVELS) << 1) - 5'd1) begin
                    state <= div_init;
                    div_phase <= 0;
                end else begin
                    vwap_cnt <= vwap_cnt + 5'd1;
                    if (vwap_cnt == 5'(VWAP_LEVELS) - 5'd1) begin
                        rd_level <= 0; // switch to ask next cyc
                        rd_side <= 1;
                    end else begin
                        rd_level <= rd_level + 4'd1; 
                    end
                end
            end

            div_init: begin //binary div
                if (div_phase == 0) begin
                    if (sum_bid_size == 0) begin //zero size top 3
                        bid_vwap <= best_bid_price;
                        div_phase <= 1; //back to div init for ask
                    end else begin
                        div_P <= {1'b0, sum_bid_weighted[127:64]}; //running remainder
                        div_A_lo <= sum_bid_weighted[63:0]; 
                        div_D <= sum_bid_size;
                        div_Q <= 0;
                        div_cnt <= 0;
                        state <= div_run;
                    end
                end else begin
                    if (sum_ask_size == 0) begin
                        ask_vwap <= best_ask_price;
                        state <= mid_calc;
                    end else begin
                        div_P <= {1'b0, sum_ask_weighted[127:64]};
                        div_A_lo <= sum_ask_weighted[63:0];
                        div_D <= sum_ask_size;
                        div_Q <= '0;
                        div_cnt <= '0;
                        state <= div_run;
                    end
                end
            end

            div_run: begin
                div_P <= Q_bit ? P_trial - {1'b0, div_D} : P_trial; //q bit 1 when > divisor
                div_Q <= {div_Q[62:0], Q_bit};
                div_A_lo <= {div_A_lo[62:0], 1'b0};
                div_cnt <= div_cnt + 6'd1;

                if (div_cnt == 6'd63) begin
                    if (div_phase == 0) begin
                        bid_vwap <= {div_Q[62:0], Q_bit};
                        div_phase <= 1;
                        state <= div_init;
                    end else begin
                        ask_vwap <= {div_Q[62:0], Q_bit};
                        state <= mid_calc;
                    end
                end
            end

            // Simple average of the two VWAP prices. Both are < 2^63
            // (prices in PRICE9 for realistic futures), so the 65-bit add
            // never overflows bit 64.
            mid_calc: begin
                mid_price <= ({1'b0, bid_vwap} + {1'b0, ask_vwap}) >> 1;
                state <= quote_calc;
            end

            // bid_q_raw / ask_q_raw are combinational, updated immediately
            // when mid_price was registered in MID_CALC. Latch them here.
            // Sign bit [64] indicates negative price → clamp to 0.
            // Crossed spread (extreme skew) → zero sizes → EMIT won't fire.
            quote_calc: begin
                if (!bid_q_raw[64] && !ask_q_raw[64] && (ask_q_raw > bid_q_raw)) begin
                    bid_price <= bid_q_raw[63:0];
                    ask_price <= ask_q_raw[63:0];
                    bid_size <= QUOTE_SIZE;
                    ask_size <= QUOTE_SIZE;
                end else begin
                    bid_price <= '0;
                    ask_price <= '0;
                    bid_size <= '0;
                    ask_size <= '0;
                end
                state <= risk;
            end

            // Evaluate all three risk limits and latch risk_breach for EMIT.
            // Limits:
            //   1. Absolute position exceeds MAX_POSITION contracts.
            //   2. Quote refresh rate exceeds MAX_ORDER_RATE per second.
            //   3. Session PnL (mark-to-mid) fell below -LOSS_LIMIT.
            risk: begin
                risk_breach <=
                    (net_position > $signed({1'b0, MAX_POSITION})) ||
                    (net_position < -$signed({1'b0, MAX_POSITION})) ||
                    (order_count >= MAX_ORDER_RATE) ||
                    (daily_pnl < -$signed({64'h0, LOSS_LIMIT}));
                state <= emit;
            end

            // Cancel-replace: always cancel before posting.
            // Layer 8 handles spurious cancels with no live order gracefully.
            // quote_valid suppressed when risk is breached, book is invalid,
            // gap is active, or the computed prices are zero/crossed.
            emit: begin
                if (book_valid && !gap_detected) begin
                    cancel_bid <= 1;
                    cancel_ask <= 1;
                    if (!risk_breach && bid_price != '0 && ask_price != '0) begin
                        quote_valid <= 1;
                        order_count <= order_count + 16'd1;
                    end
                end
                state <= idle;
            end

            default: state <= idle;

        endcase
    end
end
endmodule
