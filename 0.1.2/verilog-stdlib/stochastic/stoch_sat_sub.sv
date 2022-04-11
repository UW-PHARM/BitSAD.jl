`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 02/28/2018 08:37:06 PM
// Module Name: stoch_sat_sub
// Description:
//  Performs max(a - b, 0)
//////////////////////////////////////////////////////////////////////////////////
module stoch_sat_sub (
    input logic CLK,
    input logic nRST,
    input logic a,
    input logic b,
    output logic y
);

localparam COUNTER_SIZE = 8;
localparam COUNTER_ONE = {{(COUNTER_SIZE-1){1'b0}}, 1'b1};

// internal wires
logic c;
logic inc, dec;
logic [(COUNTER_SIZE-1):0] count_up;
logic [(COUNTER_SIZE-1):0] counter;
logic [(COUNTER_SIZE-1):0] next_counter;

assign c = a ^ b;
assign inc = c & a;
assign dec = c & b;
assign count_up = inc ? (counter + COUNTER_ONE) :
                  (dec ? ((|counter) ? (counter - COUNTER_ONE) : {COUNTER_SIZE{1'b0}}) : counter);

assign y = (count_up >= COUNTER_ONE) ? 1'b1 : 1'b0;
assign next_counter = (|count_up) ? count_up : (count_up - y);

always @(posedge CLK) begin
    if (!nRST) counter <= {COUNTER_SIZE{1'b0}};
    else counter <= next_counter;
end

endmodule
