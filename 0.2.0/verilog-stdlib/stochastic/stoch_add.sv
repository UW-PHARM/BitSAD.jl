`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/01/2018 11:30:40 AM
// Module Name: stoch_add
// Description:
//  Adds two stochastic bitstreams.
//////////////////////////////////////////////////////////////////////////////////
module stoch_add (
    input logic CLK,
    input logic nRST,
    input logic a,
    input logic b,
    output logic y
);

localparam COUNTER_SIZE = 8;

// internal wires
logic [COUNTER_SIZE-1:0] c;
logic [COUNTER_SIZE-1:0] counter, next_counter;

assign c = counter + a + b;
assign y = (c >= {{(COUNTER_SIZE - 1){1'b0}}, 1'b1}) ? 1'b1 : 1'b0;

always @(posedge CLK) begin
    if (!nRST) counter <= {COUNTER_SIZE{1'b0}};
    else counter <= next_counter;
end

always @(c, y) begin
    if (~|c & y) next_counter <= {COUNTER_SIZE{1'b0}};
    else next_counter <= c - y;
end

endmodule
