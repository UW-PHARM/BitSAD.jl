`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_8
// Description:
//  A simple 8 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_8 (
    input logic CLK,
    input logic nRST,
    input logic [7:0] inputs,
    output logic [3:0] sum
);

logic [1:0][2:0] inner_sum;

adder_tree_4 tree1 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[3:0]),
        .sum(inner_sum[0])
    );

adder_tree_4 tree2 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[7:4]),
        .sum(inner_sum[1])
    );

assign sum = inner_sum[0] + inner_sum[1];

endmodule
