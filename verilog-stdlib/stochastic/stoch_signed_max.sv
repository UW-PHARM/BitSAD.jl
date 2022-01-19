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
module stoch_signed_max (
    input logic CLK,
    input logic nRST,
    input logic a_p,
    input logic a_m,
    input logic b_p,
    input logic b_m,
    output logic y_p,
    output logic y_m
);

localparam COUNTER_SIZE = 8;
localparam COUNTER_ONE = {{(COUNTER_SIZE - 1){1'b0}}, 1'b1};

logic a_sub_b_p, a_sub_b_m;
logic inc, dec;
logic [(COUNTER_SIZE - 1):0] counter;
logic [(COUNTER_SIZE - 1):0] next_counter;

stoch_signed_sub sub (
        .CLK(CLK),
        .nRST(nRST),
        .a_p(a_p),
        .a_m(a_m),
        .b_p(b_p),
        .b_m(b_m),
        .y_p(a_sub_b_p),
        .y_m(a_sub_b_m)
    );

assign inc = a_sub_b_p & ~a_sub_b_m;
assign dec = a_sub_b_m & ~a_sub_b_p;
assign next_counter = inc ? counter + COUNTER_ONE :
                      dec ? counter - COUNTER_ONE :
                      counter;

always @(posedge CLK) begin
    if (!nRST) counter <= {COUNTER_SIZE{1'b0}};
    else counter <= next_counter;
end

endmodule
