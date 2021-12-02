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
module stoch_signed_sub(CLK, nRST, a_p, a_m, b_p, b_m, y_p, y_m);

parameter COUNTER_SIZE = 8;

input CLK, nRST;
input a_p, a_m;
input b_p, b_m;
output y_p, y_m;

wire s_pp, s_pm, s_mp, s_mm;

stoch_sat_sub #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) subpp (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_p),
        .b(b_p),
        .y(s_pp)
    );

stoch_sat_sub #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) subpm (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_p),
        .b(b_m),
        .y(s_pm)
    );

stoch_sat_sub #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) submp (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_m),
        .b(b_p),
        .y(s_mp)
    );

stoch_sat_sub #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) submm (
        .CLK(CLK),
        .nRST(nRST),
        .a(a_m),
        .b(b_m),
        .y(s_mm)
    );

stoch_add #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) addp (
        .CLK(CLK),
        .nRST(nRST),
        .a(s_pp),
        .b(s_pm),
        .y(y_p)
    );

stoch_add #(
        .COUNTER_SIZE(COUNTER_SIZE)
    ) addm (
        .CLK(CLK),
        .nRST(nRST),
        .a(s_mp),
        .b(s_mm),
        .y(y_m)
    );

endmodule
