`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 12/01/2021
// Module Name: stoch_signed_sub_mat
// Description:
//  Instantiates a stochastic matrix substractor.
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_sub_mat #(
    parameter NUM_ROWS = 2,
    parameter NUM_COLS = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] A_p,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] A_m,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] B_p,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] B_m,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y_p,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y_m
);

genvar i, j;
generate
    for (j = 0; j < NUM_COLS; j = j + 1) begin: col
        for (i = 0; i < NUM_ROWS; i = i + 1) begin : row
            stoch_signed_sub sub(
                    .CLK(CLK),
                    .nRST(nRST),
                    .a_p(A_p[i][j]),
                    .a_m(A_m[i][j]),
                    .b_p(B_p[i][j]),
                    .b_m(B_m[i][j]),
                    .y_p(Y_p[i][j]),
                    .y_m(Y_m[i][j])
                );
        end
    end
endgenerate

endmodule
