`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/25/2026 12:07:14 AM
// Design Name: 
// Module Name: order_book
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


module order_book(
    input logic clk,
    input logic rst,
 
    input logic [63:0] entry_price, //price9 from mdp
    input logic [31:0] entry_size, // # contracts
    input logic [7:0] entry_price_level, //1-10, 1 = best
    input logic [7:0] entry_update_action, // 0=New 1=Change 2=Delete
    input logic [7:0] entry_type, // 0x30=Bid 0x31=Ask
    input logic is_snapshot, //1 if from T38 snapshot
    input logic entry_valid,
    input logic mdp_done,
    input logic [31:0] mdp_seq_num,
    input logic mdp_pkt_valid,
 
    output logic [63:0] best_bid_price, //combinational
    output logic [31:0] best_bid_size,
    output logic [63:0] best_ask_price,
    output logic [31:0] best_ask_size,
 
    input logic [3:0] rd_level, //drive 0-9
    input logic rd_side, //0 buy 1 ask
    output logic [63:0] rd_price,
    output logic [31:0] rd_size,
 
    output logic book_valid, //status indicator
    output logic gap_detected
    );
    
typedef enum logic [1:0] {
    wait_s,
    live,
    gap //wait for t38
} book_state_t;
 
book_state_t book_state;
 
localparam logic [7:0] bid_type = 8'h30;
localparam logic [7:0] new_o = 8'd0;
localparam logic [7:0] change = 8'd1;
localparam logic [7:0] delete = 8'd2;

logic [63:0] bid_price [0:9]; //storage, index 0 best
logic [31:0] bid_size [0:9];
logic [63:0] ask_price [0:9];
logic [31:0] ask_size [0:9];

logic [31:0] expected_seq;
logic seq_init; //flag for init

logic snap_bid_cleared; //to ensure thin markets are not issue
logic snap_ask_cleared;

logic is_bid_entry;
logic [3:0] lvl;
 
assign is_bid_entry = (entry_type == bid_type);
assign lvl = entry_price_level[3:0] - 4'd1; //0 index

assign best_bid_price = bid_price[0];
assign best_bid_size = bid_size[0];
assign best_ask_price = ask_price[0];
assign best_ask_size = ask_size[0];
 
assign rd_price = rd_side ? ask_price[rd_level] : bid_price[rd_level];
assign rd_size = rd_side ? ask_size[rd_level] : bid_size[rd_level];
 
always_ff @(posedge clk) begin
    if (rst) begin
        book_state <= wait_s;
        expected_seq <= '0;
        seq_init <= 0;
        snap_bid_cleared <= 0;
        snap_ask_cleared <= 0;
        book_valid <= 0;
        gap_detected <= 0;
        for (int i = 0; i < 10; i++) begin
            bid_price[i] <= '0;
            bid_size[i] <= '0;
            ask_price[i] <= '0;
            ask_size[i] <= '0;
        end
    end else begin
        if (mdp_pkt_valid) begin
            if (seq_init && (mdp_seq_num != expected_seq) && (book_state == live)) begin
                book_state <= gap;
                gap_detected <= 1;
            end
            seq_init <= 1;
            expected_seq <= mdp_seq_num + 32'd1;
        end
        
        //update book
        //if (entry_valid && (entry_price_level >= 8'd1) && (entry_price_level <= 8'd10)) begin
        if (entry_valid && (lvl <= 4'd9)) begin
            if (is_snapshot || (book_state == live)) begin //check both for gaps
            
                if(is_snapshot) begin
                    if (is_bid_entry && !snap_bid_cleared) begin
                        for (int i = 0; i < 10; i++) begin
                            bid_price[i] <= '0;
                            bid_size[i] <= '0;
                        end
                        snap_bid_cleared <= 1;
                    end else if (!is_bid_entry && !snap_ask_cleared) begin
                        for (int i = 0; i < 10; i++) begin
                            ask_price[i] <= '0;
                            ask_size[i] <= '0;
                        end
                        snap_ask_cleared <= 1;
                    end
                    
                    if (is_bid_entry) begin //write entry
                        bid_price[lvl] <= entry_price;
                        bid_size[lvl] <= entry_size;
                    end else begin
                        ask_price[lvl] <= entry_price;
                        ask_size[lvl] <= entry_size;
                    end
                    
                end else begin //book must be live
                    if (is_bid_entry) begin
                        case (entry_update_action)
                            new_o: begin
                                bid_price[lvl] <= entry_price;
                                bid_size[lvl] <= entry_size;
                            end
                            change: bid_size[lvl] <= entry_size;
                            delete: begin
                                bid_price[lvl] <= 0;
                                bid_size[lvl] <= 0;
                            end
                            default: ;
                        endcase
                    end else begin //cant just alias an array for writes :(
                        case (entry_update_action)
                            new_o: begin
                                ask_price[lvl] <= entry_price;
                                ask_size[lvl] <= entry_size;
                            end
                            change: ask_size[lvl] <= entry_size;
                            delete: begin
                                ask_price[lvl] <= 0;
                                ask_size[lvl] <= 0;
                            end
                            default: ;
                        endcase
                    end
                end
            end
        end
    
        if (is_snapshot && mdp_done) begin
            book_state <= live; //can only enter live with a t38
            book_valid <= 1;
            gap_detected <= 0;
        end
        
        if (mdp_done) begin //put last so its resets win (doesnt really matter tho)
            snap_bid_cleared <= 0;
            snap_ask_cleared <= 0;
        end
    
    end
end

endmodule
