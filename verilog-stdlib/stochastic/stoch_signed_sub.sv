`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 12/01/2021
// Module Name: stoch_signed_sub
// Description: 
//  Performs a - b on signed channel stochastic numbers
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_sub (
    input logic CLK,
    input logic nRST,
    input logic a_p,
    input logic a_m,
    input logic b_p,
    input logic b_m,
    output logic y_p,
    output logic y_m
);

logic s_pp, s_pm, s_mp, s_mm;

stoch_sat_sub subpp (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_p),
        .b(b_p),
        .y(s_pp)
    );

stoch_sat_sub subpm (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_p),
        .b(b_m),
        .y(s_pm)
    );

stoch_sat_sub submp (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_m),
        .b(b_p),
        .y(s_mp)
    );

stoch_sat_sub submm (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_m),
        .b(b_m),
        .y(s_mm)
    );

stoch_add addp (
        .CLK(CLK),
        .nRST(nRST),
        .a(s_pp),
        .b(s_pm),
        .y(y_p)
    );

stoch_add addm (
        .CLK(CLK),
        .nRST(nRST),
        .a(s_mp),
        .b(s_mm),
        .y(y_m)
    );

endmodule
