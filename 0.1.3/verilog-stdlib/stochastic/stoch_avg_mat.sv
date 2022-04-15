`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 04/05/2018 07:35:15 PM
// Module Name: stoch_avg_mat
// Description:
//  Instantiates matrix of stoch_avg.
//  "A" should be a NUM_ROWS x NUM_COLS x NUM_POPS packed array port.
//////////////////////////////////////////////////////////////////////////////////
module stoch_avg_mat #(
    parameter NUM_POPS = 2,
    parameter NUM_ROWS = 3,
    parameter NUM_COLS = 3
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_ROWS-1):0][(NUM_COLS-1:0)][(NUM_POPS-1):0] A,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1:0)] Y
);

genvar i, j;
generate
    for (i = 0; i < NUM_ROWS; i = i + 1) begin : row
        for (j = 0; j < NUM_COLS; j = j + 1) begin: col
            stoch_avg #(
                .NUM_POPS(NUM_POPS)
            ) avg (
                .CLK(CLK),
                .nRST(nRST),
                .a(A[i][j]),
                .y(Y[i][j])
            );
        end
    end
endgenerate

endmodule
