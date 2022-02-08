`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 02/01/2022
// Module Name: stoch_signed_mult
// Description:
//  Instantiates a signed stochastic multiplier.
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_mult (
    input logic CLK,
    input logic nRST,
    input logic a_p,
    input logic a_m,
    input logic b_p,
    input logic b_m,
    output logic y_p,
    output logic y_m
);

logic mult_pp, mult_pm, mult_mp, mult_mm;
logic mult_11, mult_12, mult_13, mult_14;

assign mult_pp = a_p & b_p;
assign mult_pm = a_p & b_m;
assign mult_mp = a_m & b_p;
assign mult_mm = a_m & b_m;

stoch_sat_sub sub_11 (
        .CLK(CLK),
        .nRST(nRST),
        .a(mult_pp),
        .b(mult_pm),
        .y(mult_11)
    );

stoch_sat_sub sub_12 (
        .CLK(CLK),
        .nRST(nRST),
        .a(mult_pm),
        .b(mult_pp),
        .y(mult_12)
    );

stoch_sat_sub sub_13 (
        .CLK(CLK),
        .nRST(nRST),
        .a(mult_mp),
        .b(mult_mm),
        .y(mult_13)
    );

stoch_sat_sub sub_14 (
        .CLK(CLK),
        .nRST(nRST),
        .a(mult_mm),
        .b(mult_mp),
        .y(mult_14)
    );

stoch_add add_p (
        .CLK(CLK),
        .nRST(nRST),
        .a(mult_11),
        .b(mult_14),
        .y(y_p)
    );

stoch_add add_m (
        .CLK(CLK),
        .nRST(nRST),
        .a(mult_12),
        .b(mult_13),
        .y(y_m)
    );

endmodule
