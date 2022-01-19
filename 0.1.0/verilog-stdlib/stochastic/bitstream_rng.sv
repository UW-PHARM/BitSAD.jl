`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Heng Zhuo + Kyle Daruwalla
// 
// Create Date:
// Module Name: bitstream_rng
// Description:
//  Generates a stochastic bitstream based on parameters VALUE and IS_NEGATIVE.
//  Set BITWIDTH to adjust the LFSR size (20 or 64).
//////////////////////////////////////////////////////////////////////////////////
module bitstream_rng #(
    parameter BITWIDTH = 20,
    parameter VALUE = {BITWIDTH{1'b0}},
    parameter IS_NEGATIVE = 1'b0
) (
    input logic CLK,
    input logic nRST,
    output logic out_p,
    output logic out_m
);

localparam _BITWIDTH = (BITWIDTH > 20) ? 64 : 20;

logic [(_BITWIDTH - 1):0] lfsr_r;

fibonacci_lfsr #(
        .BITWIDTH(_BITWIDTH)
    ) d_lfsr (
        .CLK(CLK),
        .nRST(nRST),
        .r(lfsr_r)
    );

assign out_p = ((lfsr_r < VALUE) && !IS_NEGATIVE) ? 1'b1 : 1'b0;
assign out_m = ((lfsr_r < VALUE) && IS_NEGATIVE) ? 1'b1 : 1'b0;

endmodule
