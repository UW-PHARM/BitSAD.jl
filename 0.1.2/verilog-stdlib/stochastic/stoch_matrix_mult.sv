`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/06/2018 09:35:24 AM
// Module Name: stoch_matrix_mult
// Description:
//  Instantiates a stochastic matrix multiplier (via stoch_dot_prod).
//////////////////////////////////////////////////////////////////////////////////
module stoch_matrix_mult #(
    parameter NUM_ROWS = 2,
    parameter NUM_MID = 2,
    parameter NUM_COLS = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_ROWS-1):0][(NUM_MID-1):0] A,
    input logic [(NUM_MID-1):0][(NUM_COLS-1):0] B,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y
);

logic [(NUM_COLS-1):0][(NUM_MID-1):0] B_transpose;

integer row, col;
always @(B) begin
    for (row = 0; row < NUM_MID; row = row + 1) begin
        for (col = 0; col < NUM_COLS; col = col + 1) begin
            B_transpose[col][row] <= B[row][col];
        end
    end
end

genvar i, j;
generate
    for (i = 0; i < NUM_ROWS; i = i + 1) begin : row_gen
        for (j = 0; j < NUM_COLS; j = j + 1) begin : col_gen
            stoch_dot_prod #(
                .VEC_LEN(NUM_MID)
            ) dot_prod (
                .CLK(CLK),
                .nRST(nRST),
                .u(A[i]),
                .v(B_transpose[j]),
                .y(Y[i][j])
            );
        end
    end
endgenerate

endmodule
