`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 02/01/2022
// Module Name: stoch_signed_matrix_mult
// Description:
//  Instantiates a signed stochastic matrix multiplier.
//////////////////////////////////////////////////////////////////////////////////
module stoch_signed_matrix_mult #(
    parameter NUM_ROWS = 2,
    parameter NUM_MID = 2,
    parameter NUM_COLS = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_ROWS-1):0][(NUM_MID-1):0] A_p,
    input logic [(NUM_ROWS-1):0][(NUM_MID-1):0] A_m,
    input logic [(NUM_MID-1):0][(NUM_COLS-1):0] B_p,
    input logic [(NUM_MID-1):0][(NUM_COLS-1):0] B_m,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y_p,
    output logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] Y_m
);

logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_pp;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_pm;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_mp;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_mm;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_11;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_12;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_13;
logic [(NUM_ROWS-1):0][(NUM_COLS-1):0] mmult_out_14;

stoch_matrix_mult #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_MID(NUM_MID),
        .NUM_COLS(NUM_COLS)
    ) mmult_pp (
        .CLK(CLK),
        .nRST(nRST),
        .A(A_p),
        .B(B_p),
        .Y(mmult_out_pp)
    );
stoch_matrix_mult #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_MID(NUM_MID),
        .NUM_COLS(NUM_COLS)
    ) mmult_pm (
        .CLK(CLK),
        .nRST(nRST),
        .A(A_p),
        .B(B_m),
        .Y(mmult_out_pm)
    );
stoch_matrix_mult #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_MID(NUM_MID),
        .NUM_COLS(NUM_COLS)
    ) mmult_mp (
        .CLK(CLK),
        .nRST(nRST),
        .A(A_m),
        .B(B_p),
        .Y(mmult_out_mp)
    );
stoch_matrix_mult #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_MID(NUM_MID),
        .NUM_COLS(NUM_COLS)
    ) mmult_mm (
        .CLK(CLK),
        .nRST(nRST),
        .A(A_m),
        .B(B_m),
        .Y(mmult_out_mm)
    );
stoch_sat_sub_mat #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) mmult_11 (
        .CLK(CLK),
        .nRST(nRST),
        .A(mmult_out_pp),
        .B(mmult_out_pm),
        .Y(mmult_out_11)
    );
stoch_sat_sub_mat #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) mmult_12 (
        .CLK(CLK),
        .nRST(nRST),
        .A(mmult_out_pm),
        .B(mmult_out_pp),
        .Y(mmult_out_12)
    );
stoch_sat_sub_mat #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) mmult_13 (
        .CLK(CLK),
        .nRST(nRST),
        .A(mmult_out_mp),
        .B(mmult_out_mm),
        .Y(mmult_out_13)
    );
stoch_sat_sub_mat #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) mmult_14 (
        .CLK(CLK),
        .nRST(nRST),
        .A(mmult_out_mm),
        .B(mmult_out_mp),
        .Y(mmult_out_14)
    );
stoch_add_mat #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) mmult_p (
        .CLK(CLK),
        .nRST(nRST),
        .A(mmult_out_11),
        .B(mmult_out_14),
        .Y(Y_p)
    );
stoch_add_mat #(
        .NUM_ROWS(NUM_ROWS),
        .NUM_COLS(NUM_COLS)
    ) mmult_m (
        .CLK(CLK),
        .nRST(nRST),
        .A(mmult_out_12),
        .B(mmult_out_13),
        .Y(Y_m)
    );

endmodule
