`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_16
// Description:
//  A simple 16 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_16 (
    input logic CLK,
    input logic nRST,
    input logic [15:0] inputs,
    output logic [4:0] sum
);

logic [1:0][3:0] inner_sum;

adder_tree_8 tree1 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[7:0]),
        .sum(inner_sum[0])
    );

adder_tree_8 tree2 (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(inputs[15:8]),
        .sum(inner_sum[1])
    );

assign sum = inner_sum[0] + inner_sum[1];

endmodule
