`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/01/2018 09:38:38 AM
// Module Name: stoch_sat_sub_mat
// Description:
//  Instantiates a stochastic matrix substractor.
//////////////////////////////////////////////////////////////////////////////////
module stoch_sat_sub_mat #(
    parameter NUM_ROWS = 2,
    parameter NUM_COLS = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] A,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] B,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y
);

genvar i, j;
generate
    for (i = 0; i < NUM_ROWS; i = i + 1) begin : row
        for (j = 0; j < NUM_COLS; j = j + 1) begin: col
            stoch_sat_sub sub(
                    .CLK(CLK),
                    .nRST(nRST),
                    .a(A[i][j]),
                    .b(B[i][j]),
                    .y(Y[i][j])
                );
        end
    end
endgenerate

endmodule
