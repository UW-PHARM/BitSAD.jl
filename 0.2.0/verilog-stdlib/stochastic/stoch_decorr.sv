`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/04/2018 03:16:40 AM
// Module Name: stoch_decorr
// Description:
//  Decorrelates stochastic bitstream.
//  Set LFSR_WIDTH to 20 or 64 to choose the LFSR size.
//////////////////////////////////////////////////////////////////////////////////
module stoch_decorr #(
    parameter LFSR_WIDTH = 64
) (
    input logic CLK,
    input logic nRST,
    input logic a,
    output logic y
);

localparam STEP_VAL = 16;
localparam COUNTER_SIZE = 8;
localparam _LFSR_WIDTH = (LFSR_WIDTH == 20) ? 20 : 64;

// internal wires
logic [(COUNTER_SIZE-1):0] c;
logic [1:0] buffer, next_buffer;
logic [(COUNTER_SIZE-1):0] counter, next_counter;
logic [(_LFSR_WIDTH-1):0] r;
logic shift_in;
logic [(COUNTER_SIZE-1):0] dec;

fibonacci_lfsr #(
        .BITWIDTH(_LFSR_WIDTH)
    ) lfsr(
        .CLK(CLK),
        .nRST(nRST),
        .r(r)
    );

assign c = (a == 1'b1) ? counter + STEP_VAL : counter;
assign shift_in = (r[(NEW_COUNTER_SIZE-1):0] <= counter) ? 1'b1 : 1'b0;
assign y = buffer[1];
assign dec = (y == 1'b1) ? c - STEP_VAL : c;

always @(posedge CLK) begin
    if (!nRST) begin
        counter <= {NEW_COUNTER_SIZE{1'b0}};
        buffer <= 2'd0;
    end
    else begin
        counter <= next_counter;
        buffer <= next_buffer;
    end
end

always @(c, y) begin
    if ((c < STEP_VAL) & y) next_counter <= {NEW_COUNTER_SIZE{1'b0}};
    else next_counter <= dec;
end

always @(buffer, shift_in) begin
    next_buffer <= {buffer[0], shift_in};
end

endmodule
