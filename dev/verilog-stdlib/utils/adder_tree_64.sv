`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_64
// Description:
//  A simple 64 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_64 (
    input logic CLK,
    input logic nRST,
    input logic [63:0] inputs,
    output logic [6:0] sum
);

logic [1:0][5:0] inner_sum;

adder_tree_32 tree1 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[31:0]),
        .sum(inner_sum[0])
    );

adder_tree_32 tree2 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[63:32]),
        .sum(inner_sum[1])
    );

assign sum = inner_sum[0] + inner_sum[1];

endmodule
