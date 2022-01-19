`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/06/2018 02:48:06 PM
// Module Name: stoch_fixed_gain_div_mat
// Description:
// 	Instantiates stoch_fixed_gain_div for matrices.
//////////////////////////////////////////////////////////////////////////////////
module stoch_fixed_gain_div_mat #(
    parameter GAIN = 2,
    parameter NUM_ROWS = 2,
    parameter NUM_COLS = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] A,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y
);

genvar i, j;
generate
    for (i = 0; i < NUM_ROWS; i = i + 1) begin : row
        for (j = 0; j < NUM_COLS; j = j + 1) begin: col
            stoch_fixed_gain_div #(
                    .GAIN(GAIN)
                ) div(
                    .CLK(CLK),
                    .nRST(nRST),
                    .a(A[i][j]),
                    .y(Y[i][j])
                );
        end
    end
endgenerate

endmodule
