`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Rishi Bala
// 
// Create Date: 05/15/2026 10:46:50 PM
// Design Name: 
// Module Name: ip_parser
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


module ip_parser(
    input logic clk,
    input logic rst,
    input logic [7:0] payload, //from eth parser
    input logic payload_valid,
    input logic header_valid,
    input logic [15:0] ether,
    input logic frame_done,
    input logic error,
    
    //header fields
    output logic [3:0] ip_version,
    output logic [3:0]ip_ihl,
    output logic [7:0] ip_dscp,
    output logic [15:0] ip_total_len,
    output logic [15:0] ip_id,
    output logic [2:0] ip_flags,
    output logic [12:0] ip_frag_offset,
    output logic [7:0] ip_ttl,
    output logic [7:0] ip_protocol, //6 is tcp, 7=udp, 1=icmp
    output logic [15:0] ip_checksum,
    output logic [31:0] ip_src,
    output logic [31:0] ip_dest,
    output logic ip_header_valid,
    output logic ip_checksum_val,
    output logic ip_is_fragment,
    
    output logic [7:0] ip_payload_data,
    output logic ip_payload_valid,
    output logic ip_payload_done,
    output logic ip_error
);

    typedef enum logic [3:0] {
        IDLE,
        VER_IHL, //0
        DSCP_ECN, //1
        TOT_LEN, //2-3
        IP_IDENT, //4-5
        FLAGS_FRAG, //6-7
        TTL, //8
        PROTO, //9
        CHKSUM, //10-11
        SRC, //12-15
        DST, //16-19
        OPTIONS, //20+ (if IHL > 5)
        PAYLOAD, //rest
        DROP
    } state_t;

state_t state;
logic [3:0] cnt;
logic [7:0] options_left;

//checksum
logic [7:0] checksum_in;
logic [15:0] checksum;
logic phase;

logic [16:0] next;
always_comb begin
    next = {1'b0, checksum} + {1'b0, checksum_in, payload};
    if(next[16]) next = {1'b0, next[15:0]} + 17'h1; //1s complement
end

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        cnt  <= 0;
        options_left <= 0;
        ip_version <= 0;
        ip_ihl <= 0;
        ip_dscp <= 0;
        ip_total_len <= 0;
        ip_id <= 0;
        ip_flags <= 0;
        ip_frag_offset <= 0;
        ip_ttl <= 0;
        ip_protocol <= 0;
        ip_checksum <= 0;
        ip_src <= 0;
        ip_dest <= 0;
        ip_header_valid <= 0;
        ip_checksum_val <= 0;
        ip_is_fragment <= 0;
        ip_payload_data <= 0;
        ip_payload_valid <= 0;
        ip_payload_done <= 0;
        ip_error <= 0;
        checksum_in <= 0;
        checksum <= 0;
        phase <= 0;
    end else begin

        ip_header_valid  <= 0;
        ip_payload_valid <= 0;
        ip_payload_done  <= 0;
        ip_error         <= 0;
        
        if(error) begin
            ip_error <= 1;
            state <= IDLE;
            cnt <= 0;
        end else if(frame_done) begin
            if(state == PAYLOAD) ip_payload_done <= 1;
            else if (state != IDLE) ip_error <= 1;
            state <= IDLE;
            cnt <= 0;
        end else if(header_valid) begin
            if(ether == 16'h0800) begin //ignore other than IPv4
                state     <= VER_IHL;
                cnt       <= '0;
                checksum   <= '0;
                phase <= '0;
            end
        end else if(payload_valid && state != IDLE) begin
            if(state != PAYLOAD && state != DROP) begin
                if(!phase) begin checksum_in <= payload; //latch high byte
                end else checksum <= next[15:0];
                phase <= ~phase;
            end
            
            unique case (state)
                VER_IHL: begin //header = IHL * 4 bytes
                   ip_version <= payload[7:4];;
                   ip_ihl <= payload[3:0];
                   
                   if(payload[7:4] != 4'h4 || payload[3:0] < 4'h5) state <= DROP;
                   else state <= DSCP_ECN;
                end
                
                DSCP_ECN: begin
                    ip_dscp <= payload;
                    state <= TOT_LEN;
                end
                
                TOT_LEN: begin
                    ip_total_len <= {ip_total_len[7:0], payload};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        cnt <= 0;
                        state <= IP_IDENT;
                    end
                end
                
                IP_IDENT: begin
                    ip_id <= {ip_id[7:0], payload};
                    cnt <= cnt + 1;
                    if(cnt >= 1) begin
                        cnt <= 0;
                        state <= FLAGS_FRAG;
                    end
                end
                
                FLAGS_FRAG: begin
                    cnt <= cnt + 1;
                    if (cnt == 0) begin
                        ip_flags <= payload[7:5];
                        ip_frag_offset[12:8] <= payload[4:0];
                    end else begin
                        ip_frag_offset[7:0] <= payload;
                        cnt <= 0;
                        state <= TTL;
                    end
                end
                
                TTL: begin
                    ip_ttl <= payload;
                    state <= PROTO;
                end
                
                PROTO: begin
                    ip_protocol <= payload;
                    state <= CHKSUM;
                end
                
                CHKSUM: begin
                    ip_checksum <= {ip_checksum[7:0], payload};
                    cnt <= cnt + 1;
                    if (cnt >= 1) begin 
                        cnt <= 0; 
                        state <= SRC; 
                    end
                end
                
                SRC: begin
                    ip_src <= {ip_src[23:0], payload};
                    cnt <= cnt + 1;
                    if (cnt >= 3) begin 
                        cnt <= 0; 
                        state <= DST; 
                    end
                end
                
                DST: begin
                    ip_dest <= {ip_dest[23:0], payload};
                    cnt <= cnt + 1;
                    if (cnt >= 3) begin 
                        cnt <= 0; 
                        ip_is_fragment <= ip_flags[0] | (|ip_frag_offset); //MF | offset bit
                        //only 0 if offset is 0 and no fragments left
                        
                        if(ip_ihl > 4'h5) begin
                            options_left <= ((ip_ihl - 4'h5) << 2) - 1; //extra words, mul by 4, sub 1
                            state <= OPTIONS;
                        end else begin 
                            ip_checksum_val <= (next[15:0] == 16'hFFFF);
                            ip_header_valid <= 1;
                            state <= PAYLOAD;
                        end
                    end
                end
                
                OPTIONS: begin //dont parse
                    if(options_left == 0) begin //last byte
                        ip_checksum_val <= (next[15:0] == 16'hFFFF);
                        ip_header_valid <= 1;
                        state <= PAYLOAD;
                    end else options_left <= options_left - 1;
                end
                
                PAYLOAD: begin
                    ip_payload_data <= payload;
                    ip_payload_valid <= 1;
                end
                
                DROP: ; //absorb remaining bytes
            endcase
        end
    end
end
endmodule
