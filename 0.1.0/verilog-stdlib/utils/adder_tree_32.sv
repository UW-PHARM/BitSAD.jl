`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_32
// Description:
//  A simple 32 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_32 (
    input logic CLK,
    input logic nRST,
    input logic [31:0] inputs,
    output logic [5:0] sum
);

logic [1:0][4:0] inner_sum;

adder_tree_16 tree1 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[15:0]),
        .sum(inner_sum[0])
    );

adder_tree_16 tree2 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[31:16]),
        .sum(inner_sum[1])
    );

assign sum = inner_sum[0] + inner_sum[1];

endmodule
