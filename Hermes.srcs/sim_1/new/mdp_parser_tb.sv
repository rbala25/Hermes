`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/24/2026 08:00:55 PM
// Design Name: 
// Module Name: mdp_parser_tb
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


module mdp_parser_tb;

logic clk = 0;
always #10 clk = ~clk;

logic rst;
logic [7:0] udp_payload;
logic udp_payload_valid;
logic udp_payload_done;
logic udp_header_valid;
logic [15:0] udp_dest;
logic udp_error;
logic [31:0] mdp_seq_num;
logic [63:0] mdp_sending_time;
logic mdp_pkt_valid;
logic [63:0] entry_price;
logic [31:0] entry_size;
logic [7:0] entry_price_level;
logic [7:0] entry_update_action;
logic [7:0] entry_type;
logic is_snapshot;
logic entry_valid;
logic mdp_done;
logic mdp_error;

mdp_parser #(
    .port(16'd14310),
    .sec_id(32'd12345)
) dut (
    .clk(clk),
    .rst(rst),
    .udp_payload(udp_payload),
    .udp_payload_valid(udp_payload_valid),
    .udp_payload_done(udp_payload_done),
    .udp_header_valid(udp_header_valid),
    .udp_dest(udp_dest),
    .udp_error(udp_error),
    .mdp_seq_num(mdp_seq_num),
    .mdp_sending_time(mdp_sending_time),
    .mdp_pkt_valid(mdp_pkt_valid),
    .entry_price(entry_price),
    .entry_size(entry_size),
    .entry_price_level(entry_price_level),
    .entry_update_action(entry_update_action),
    .entry_type(entry_type),
    .is_snapshot(is_snapshot),
    .entry_valid(entry_valid),
    .mdp_done(mdp_done),
    .mdp_error(mdp_error)
);

//MDP header(12) + MsgSize(2) + SBE hdr(8) + root(11) + grp_dim(3) + 2*entry(32) = 100 bytes
localparam int PKT_LEN = 100;
logic [7:0] pkt [0:PKT_LEN-1];

task automatic build_pkt;
    pkt[0]=8'hE9; pkt[1]=8'h03; pkt[2]=8'h00; pkt[3]=8'h00; //mdp header w seq number 1001
    pkt[4]=8'h01; pkt[5]=8'h00; pkt[6]=8'h00; pkt[7]=8'h00; 
    pkt[8]=8'h00; pkt[9]=8'h00; pkt[10]=8'h00; pkt[11]=8'h00;

    pkt[12]=8'h58; pkt[13]=8'h00; //msg size

    pkt[14]=8'h0B; pkt[15]=8'h00; // sbe header block length 11, id 46
    pkt[16]=8'h2E; pkt[17]=8'h00;
    pkt[18]=8'h09; pkt[19]=8'h00;
    pkt[20]=8'h08; pkt[21]=8'h00;

    pkt[22]=8'h01; pkt[23]=8'h00; pkt[24]=8'h00; pkt[25]=8'h00; //root all skip
    pkt[26]=8'h00; pkt[27]=8'h00; pkt[28]=8'h00; pkt[29]=8'h00; 
    pkt[30]=8'h01;    
    pkt[31]=8'h00; pkt[32]=8'h00;                           

    
    pkt[33]=8'h20; pkt[34]=8'h00; //Block length=32
    pkt[35]=8'h02; //2 entries

    //entry 1
    pkt[36]=8'hE8; pkt[37]=8'h03; pkt[38]=8'h00; pkt[39]=8'h00; //price = 1000
    pkt[40]=8'h00; pkt[41]=8'h00; pkt[42]=8'h00; pkt[43]=8'h00;
    pkt[44]=8'h64; pkt[45]=8'h00; pkt[46]=8'h00; pkt[47]=8'h00; //MDEntrySize=100
    pkt[48]=8'h39; pkt[49]=8'h30; pkt[50]=8'h00; pkt[51]=8'h00; //SecurityID=12345
    pkt[52]=8'h00; pkt[53]=8'h00; pkt[54]=8'h00; pkt[55]=8'h00; //skip lol
    pkt[56]=8'h00; pkt[57]=8'h00; pkt[58]=8'h00; pkt[59]=8'h00; 
    pkt[60]=8'h01; // pricelevel 1
    pkt[61]=8'h00; //new
    pkt[62]=8'h30; //bid
    pkt[63]=8'h00; pkt[64]=8'h00; pkt[65]=8'h00; pkt[66]=8'h00; pkt[67]=8'h00; //pad

    //entry 2
    pkt[68]=8'hD0; pkt[69]=8'h07; pkt[70]=8'h00; pkt[71]=8'h00; //price 2000
    pkt[72]=8'h00; pkt[73]=8'h00; pkt[74]=8'h00; pkt[75]=8'h00;
    pkt[76]=8'hC8; pkt[77]=8'h00; pkt[78]=8'h00; pkt[79]=8'h00; //size 200
    pkt[80]=8'h39; pkt[81]=8'h30; pkt[82]=8'h00; pkt[83]=8'h00; //SecurityID=12345
    pkt[84]=8'h00; pkt[85]=8'h00; pkt[86]=8'h00; pkt[87]=8'h00; 
    pkt[88]=8'h00; pkt[89]=8'h00; pkt[90]=8'h00; pkt[91]=8'h00;
    pkt[92]=8'h02; //Price level 2
    pkt[93]=8'h01; //change
    pkt[94]=8'h31; //ask
    pkt[95]=8'h00; pkt[96]=8'h00; pkt[97]=8'h00; pkt[98]=8'h00; pkt[99]=8'h00;
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

int entry_count = 0;

logic [63:0] cap_price [0:1];
logic [31:0] cap_size [0:1];
logic [7:0] cap_level [0:1];
logic [7:0] cap_action [0:1];
logic [7:0] cap_type [0:1];

logic done_seen = 0;
always @(posedge clk) if (mdp_done) done_seen <= 1;

// capture entries when entry_valid fires
always @(negedge clk) begin
    if (entry_valid) begin
        cap_price[entry_count]  = entry_price;
        cap_size[entry_count]   = entry_size;
        cap_level[entry_count]  = entry_price_level;
        cap_action[entry_count] = entry_update_action;
        cap_type[entry_count]   = entry_type;
        entry_count = entry_count + 1;
    end
end

initial begin
    rst = 1;
    udp_payload = 0;
    udp_payload_valid = 0;
    udp_payload_done = 0;
    udp_header_valid = 0;
    udp_dest = 0;
    udp_error = 0;

    repeat(5) @(posedge clk);
    rst = 0;
    repeat(2) @(posedge clk);

    build_pkt();
    send_pkt();

    wait(done_seen);
    repeat(2) @(posedge clk);

    //mdp header checks
    if (mdp_seq_num !== 32'd1001)
        $display("FAIL: seq_num=%0d expected 1001", mdp_seq_num);
    else
        $display("PASS: seq_num=1001");

    if (mdp_sending_time !== 64'd1)
        $display("FAIL: sending_time=%0d expected 1", mdp_sending_time);
    else
        $display("PASS: sending_time=1");

    //entry count
    if (entry_count !== 2)
        $display("FAIL: entry_count=%0d expected 2", entry_count);
    else
        $display("PASS: 2 entries fired");

    //entry 1
    if (cap_price[0] !== 64'd1000)
        $display("FAIL: e1 price=%0d expected 1000", cap_price[0]);
    else
        $display("PASS: e1 price=1000");

    if (cap_size[0] !== 32'd100)
        $display("FAIL: e1 size=%0d expected 100", cap_size[0]);
    else
        $display("PASS: e1 size=100");

    if (cap_level[0] !== 8'd1)
        $display("FAIL: e1 level=%0d expected 1", cap_level[0]);
    else
        $display("PASS: e1 level=1");

    if (cap_action[0] !== 8'h00)
        $display("FAIL: e1 action=0x%02X expected 0x00 (New)", cap_action[0]);
    else
        $display("PASS: e1 action=New");

    if (cap_type[0] !== 8'h30)
        $display("FAIL: e1 type=0x%02X expected 0x30 (Bid)", cap_type[0]);
    else
        $display("PASS: e1 type=Bid");

    //entry 2
    if (cap_price[1] !== 64'd2000)
        $display("FAIL: e2 price=%0d expected 2000", cap_price[1]);
    else
        $display("PASS: e2 price=2000");

    if (cap_size[1] !== 32'd200)
        $display("FAIL: e2 size=%0d expected 200", cap_size[1]);
    else
        $display("PASS: e2 size=200");

    if (cap_level[1] !== 8'd2)
        $display("FAIL: e2 level=%0d expected 2", cap_level[1]);
    else
        $display("PASS: e2 level=2");

    if (cap_action[1] !== 8'h01)
        $display("FAIL: e2 action=0x%02X expected 0x01 (Change)", cap_action[1]);
    else
        $display("PASS: e2 action=Change");

    if (cap_type[1] !== 8'h31)
        $display("FAIL: e2 type=0x%02X expected 0x31 (Ask)", cap_type[1]);
    else
        $display("PASS: e2 type=Ask");

    $display("done");
    $finish;
end

initial begin
    #500000;
    $display("FAIL: timeout");
    $finish;
end

endmodule
