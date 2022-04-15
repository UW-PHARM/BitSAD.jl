`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_4
// Description:
//  A simple 4 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_4 (
    input logic CLK,
    input logic nRST,
    input logic [3:0] inputs,
    output logic [2:0] sum
);

logic [1:0][1:0] inner_sum;

adder_tree_2 tree1 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[1:0]),
        .sum(inner_sum[0])
    );

adder_tree_2 tree2 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[3:2]),
        .sum(inner_sum[1])
    );

assign sum = inner_sum[0] + inner_sum[1];

endmodule
