`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM 
// Engineer: Kyle Daruwalla
// 
// Create Date: 12/02/2021
// Module Name: stoch_signed_max
// Description: 
//  Takes the max(a, b) where a and b are signed channel stochastic bitstreams.
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_max(CLK, nRST, a_p, a_m, b_p, b_m, y_p, y_m);

parameter COUNTER_SIZE = 8;
localparam COUNTER_ONE = {{(COUNTER_SIZE - 1){1'b0}}, 1'b1};

input CLK, nRST;
input a_p, a_m, b_p, b_m;
output y_p, y_m;

wire a_sub_b_p, a_sub_b_m;
reg [(COUNTER_SIZE - 1):0] counter;
wire [(COUNTER_SIZE - 1):0] next_counter;

stoch_signed_sub #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) sub (
        .CLK(CLK),
        .nRST(nRST),
        .a_p(a_p),
        .a_m(a_m),
        .b_p(b_p),
        .b_m(b_m),
        .y_p(a_sub_b_p),
        .y_m(a_sub_b_m)
    );

assign next_counter = inc ? counter + COUNTER_ONE :
                      dec ? counter - COUNTER_ONE :
                      counter;

always @(posedge CLK) begin
    if (!nRST) counter <= {COUNTER_SIZE{1'b0}};
    else counter <= next_counter;
end

endmodule
