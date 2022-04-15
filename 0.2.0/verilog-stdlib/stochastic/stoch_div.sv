`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/04/2018 01:02:29 PM
// Module Name: stoch_div
// Description:
//  Computes the stochastic quotient y = a / b
//////////////////////////////////////////////////////////////////////////////////
module stoch_div #(
    parameter LFSR_WIDTH = 64
) (
    input logic CLK,
    input logic nRST,
    input logic a,
    input logic b,
    output logic y
);

localparam COUNTER_SIZE = 10;
localparam _LFSR_WIDTH = (LFSR_WIDTH == 20) ? 20 : 64;

// internal wires
logic signed [(COUNTER_SIZE-1):0] counter, next_counter;
logic b_and;
logic next_b_and;
logic [1:0] a_x2, b_and_x2;
logic signed [(COUNTER_SIZE-1):0] new_counter;
logic [(_LFSR_WIDTH-1):0] r;

fibonacci_lfsr #(
        .BITWIDTH(_LFSR_WIDTH)
    ) lfsr(
        .CLK(CLK),
        .nRST(nRST),
        .r(r)
    );

assign a_x2 = a << 1;
assign b_and_x2 = b_and << 1;
assign new_counter = counter + a_x2 - b_and_x2;
assign y = (next_counter > $signed({{(COUNTER_SIZE-5){1'b0}}, r[5:0]})) ? 1'b1 : 1'b0;
assign next_b_and = y & b;

always @(posedge CLK) begin
    if (!nRST) begin
        counter <= {COUNTER_SIZE{1'b0}};
        b_and <= 1'b0;
    end
    else begin
        counter <= next_counter;
        b_and <= next_b_and;
    end
end

always @(new_counter) begin
    if (new_counter < -8'sd100) next_counter <= -8'sd100;
    else next_counter <= new_counter;
end

endmodule
