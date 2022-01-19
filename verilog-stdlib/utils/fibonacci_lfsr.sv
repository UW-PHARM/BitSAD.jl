`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 12/05/2021
// Module Name: fibonacci_lfsr_20
// Description:
//  Generates a pseudorandom integer using a Fibonacci LFSR.
//  Set BITWIDTH to choose the LFSR width (20 or 64).
//////////////////////////////////////////////////////////////////////////////////
module fibonacci_lfsr #(
    parameter SEED = 64'hFEEDBABEDEADBEEF,
    parameter BITWIDTH = 64
) (
    input logic CLK,
    input logic nRST,
    output logic [(BITWIDTH-1):0] r
);

generate
    if (BITWIDTH == 20) begin
        fibonacci_lfsr_20 d_lfsr (
                .CLK(CLK),
                .nRST(nRST),
                .r(r)
            );
    end
    else begin
        fibonacci_lfsr_64 d_lfsr (
                .CLK(CLK),
                .nRST(nRST),
                .r(r)
            );
    end
endgenerate

endmodule
