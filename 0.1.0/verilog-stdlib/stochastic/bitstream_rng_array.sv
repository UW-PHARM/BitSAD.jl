`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date:
// Module Name: bitstream_rng_array
// Description:
//  Generates a stochastic bitstream arrays based on parameters VALUE and IS_NEGATIVE.
//  Set BITWIDTH to the size of each element in VALUE.
//  Set NUM_ELEMENTS to the number of elements in the array.
//////////////////////////////////////////////////////////////////////////////////
module bitstream_rng_array #(
    parameter NUM_ELEMENTS = 1,
    parameter BITWIDTH = 20,
    parameter VALUE = {BITWIDTH{1'b0}},
    parameter IS_NEGATIVE = 1'b0
) (
    input logic CLK,
    input logic nRST,
    output logic [(NUM_ELEMENTS-1):0] out_p,
    output logic [(NUM_ELEMENTS-1):0] out_m
);

localparam MAX_LOOP = (NUM_ELEMENTS < 10) ? 1 : 50;

genvar blk, i;
generate
for (blk = 0; blk < NUM_ELEMENTS / MAX_LOOP; blk = blk + 1) begin : blk_gen
    for (i = blk * MAX_LOOP; i < MAX_LOOP; i = i + 1) begin : i_gen
        bitstream_rng #(
                .BITWIDTH(BITWIDTH),
                .VALUE(VALUE[i*BITWIDTH +: BITWIDTH]),
                .IS_NEGATIVE(IS_NEGATIVE[i])
            ) rng (
                .CLK(CLK),
                .nRST(nRST),
                .out_p(out_p[i]),
                .out_m(out_m[i])
            );
    end
end

for (i = MAX_LOOP * (NUM_ELEMENTS / MAX_LOOP); i < NUM_ELEMENTS; i = i + 1) begin : i_rem_gen
    bitstream_rng #(
            .BITWIDTH(BITWIDTH),
            .VALUE(VALUE[i*BITWIDTH +: BITWIDTH]),
            .IS_NEGATIVE(IS_NEGATIVE[i])
        ) rng (
            .CLK(CLK),
            .nRST(nRST),
            .out_p(out_p[i]),
            .out_m(out_m[i])
        );
end
endgenerate

endmodule
