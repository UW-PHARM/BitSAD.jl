`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/06/2018 10:53:28 AM
// Module Name: stoch_l2_norm
// Description:
//  Computers the L2 norm of (up - un).
//////////////////////////////////////////////////////////////////////////////////
module stoch_l2_norm #(
    parameter STEP_VAL = 16,
    parameter VEC_LEN = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(VEC_LEN-1):0] up,
    input logic [(VEC_LEN-1):0] un,
    output logic yp,
    output logic yn
);

// internal wires
logic [(VEC_LEN-1):0] u, u_decorr;
logic y_sq;

assign u = up | un;

stoch_decorr_mat #(
        .STEP_VAL(STEP_VAL),
        .NUM_ROWS(VEC_LEN),
        .NUM_COLS(1)
    ) decorr (
        .CLK(CLK),
        .nRST(nRST),
        .A(u),
        .Y(u_decorr)
    );

stoch_dot_prod #(
        .VEC_LEN(VEC_LEN)
    ) dot_prod (
        .CLK(CLK),
        .nRST(nRST),
        .u(u),
        .v(u_decorr),
        .y(y_sq)
    );

stoch_square_root sq_root(
        .CLK(CLK),
        .nRST(nRST),
        .a(y_sq),
        .y(yp)
    );

assign yn = 1'b0;

endmodule
