`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_128
// Description:
//  A simple 128 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_128 (
    input logic CLK,
    input logic nRST,
    input logic [127:0] inputs,
    output logic [7:0] sum
);

logic [1:0][6:0] inner_sum;

adder_tree_64 tree1 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[63:0]),
        .sum(inner_sum[0])
    );

adder_tree_64 tree2 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[127:64]),
        .sum(inner_sum[1])
    );

assign sum = inner_sum[0] + inner_sum[1];

endmodule
