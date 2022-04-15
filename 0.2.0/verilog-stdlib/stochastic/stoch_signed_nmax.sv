`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 12/02/2021
// Module Name: stoch_signed_nmax
// Description:
//  Takes the max(as) (with as is a vector of length n)
///  where as[i] are signed channel stochastic bitstreams.
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_nmax #(
    parameter NUM_INPUTS = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_INPUTS-1):0] as_p,
    input logic [(NUM_INPUTS-1):0] as_m,
    output logic y_p,
    output logic y_m
);

logic [(NUM_INPUTS-1):0] max_outs_p, max_outs_m;

// the "initial" max_out is the first element of as
assign max_outs_p[0] = as_p[0];
assign max_outs_m[0] = as_m[0];

genvar i;
generate
for (i = 1; i < NUM_INPUTS; i = i + 1) begin : max_tree
    stoch_signed_max maxi (
            .CLK(CLK),
            .nRST(nRST),
            .a_p(max_outs_p[i - 1]),
            .a_m(max_outs_m[i - 1]),
            .b_p(as_p[i]),
            .b_m(as_m[i]),
            .y_p(max_outs_p[i]),
            .y_m(max_outs_m[i])
        );
end
endgenerate

// the last max_out is the final maximum
assign y_p = max_outs_p[NUM_INPUTS - 1];
assign y_m = max_outs_m[NUM_INPUTS - 1];

endmodule
