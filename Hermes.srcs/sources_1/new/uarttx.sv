`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/28/2026 12:29:08 PM
// Design Name: Rishi Bala
// Module Name: uarttx
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


module uarttx(output logic tx, input logic baud, input logic [7:0] data, input logic ready, input logic rst, input logic clk);
 logic [9:0] sr;
 logic busy;
 logic [3:0] count;

always_ff @(posedge clk) begin
 if(rst) begin
  sr <= 8'b0;
  busy <= 0;
  count <= 0;
  tx <= 1;
 end else if(ready && !busy) begin
  sr <= {1'b1, data, 1'b0};
  busy <= 1'b1;
  count <= 0;
 end else if(busy && baud) begin
  if(count < 10) begin
   tx <= sr[0];
   sr <= sr >> 1;
   count <= count + 1;
  end else begin
   busy <= 0;
   tx <= 1;
  end
 end
 
end

endmodule
