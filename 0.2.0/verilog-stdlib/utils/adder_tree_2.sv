`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree_2
// Description:
//  A simple two 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree_2 (
    input logic CLK,
    input logic nRST,
    input logic [1:0] inputs,
    output logic [1:0] sum
);

assign sum = inputs[0] + inputs[1];

endmodule
