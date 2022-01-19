`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/04/2018 04:00:01 PM
// Module Name: stoch_square_root
// Description:
//  Computes stochastic square root.
//////////////////////////////////////////////////////////////////////////////////
module stoch_square_root #(
    parameter LFSR_WIDTH = 64
) (
    input logic CLK,
    input logic nRST,
    input logic a,
    output logic y
);

// params
localparam COUNTER_SIZE = 10;
localparam _LFSR_WIDTH = (LFSR_WIDTH == 20) ? 20 : 64;

// internal wires
logic signed [(COUNTER_SIZE-1):0] counter, next_counter;
logic b_and;
logic next_b_and;
logic y_decorr;
logic [2:0] a_x4, b_and_x4;
logic signed [(COUNTER_SIZE-1):0] new_counter;
logic [(_LFSR_WIDTH-1):0] r;

fibonacci_lfsr #(
        .BITWIDTH(_LFSR_WIDTH)
    ) lfsr (
        .CLK(CLK),
        .nRST(nRST),
        .r(r)
    );

stoch_decorr decorr (
        .CLK(CLK),
        .nRST(nRST),
        .a(y),
        .y(y_decorr)
    );

assign a_x4 = a << 2;
assign b_and_x4 = b_and << 2;
assign new_counter = counter + a_x4 - b_and_x4;
assign y = (next_counter > $signed({{(COUNTER_SIZE-8){1'b0}}, r[8:0]})) ? 1'b1 : 1'b0;
assign next_b_and = y & y_decorr;

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
    if (new_counter < $signed({{(COUNTER_SIZE-8){1'b1}}, -8'sd100})) next_counter <= {{(COUNTER_SIZE-8){1'b1}}, -8'sd100};
    else next_counter <= new_counter;
end

endmodule
