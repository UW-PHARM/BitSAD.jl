`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM 
// Engineer: Kyle Daruwalla
// 
// Create Date: 12/01/2021
// Module Name: stoch_signed_sub_mat
// Description: 
//  Instantiates a stochastic matrix substractor.
//  Accepts inputs and outputs as column major vectors
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_sub_mat(CLK, nRST, A_p, A_m, B_p, B_m, Y_p, Y_m);

// parameters
parameter NUM_ROWS = 2;
parameter NUM_COLS = 2;

// I/O
input CLK, nRST;
input [(NUM_ROWS*NUM_COLS)-1:0] A_p, A_m, B_p, B_m;
output [(NUM_ROWS*NUM_COLS)-1:0] Y_p, Y_m;

genvar i, j;
generate
    for (j = 0; j < NUM_COLS; j = j + 1) begin: col
        for (i = 0; i < NUM_ROWS; i = i + 1) begin : row
            stoch_signed_sub sub(
                    .CLK(CLK),
                    .nRST(nRST),
                    .a_p(A_p[(j*NUM_ROWS)+i]),
                    .a_m(A_m[(j*NUM_ROWS)+i]),
                    .b_p(B_p[(j*NUM_ROWS)+i]),
                    .b_m(B_m[(j*NUM_ROWS)+i]),
                    .y_p(Y_p[(j*NUM_ROWS)+i]),
                    .y_m(Y_m[(j*NUM_ROWS)+i])
                );
        end
    end
endgenerate

endmodule
