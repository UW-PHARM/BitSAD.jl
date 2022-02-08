`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
//
// Create Date: 03/06/2018 08:48:40 AM
// Module Name: stoch_dot_prod
// Description:
//  Computes the dot product of two vectors of stochastic bitstreams
//////////////////////////////////////////////////////////////////////////////////
module stoch_dot_prod #(
    parameter VEC_LEN = 2
) (
    input logic CLK,
    input logic nRST,
    input logic [(VEC_LEN-1):0] u,
    input logic [(VEC_LEN-1):0] v,
    output logic y
);

localparam COUNTER_SIZE = $clog2(VEC_LEN) + 2;

// internal wires
logic [(VEC_LEN-1):0] c;
logic signed [(COUNTER_SIZE-1):0] sum;
logic signed [(COUNTER_SIZE-1):0] new_counter;
logic signed [(COUNTER_SIZE-1):0] counter, next_counter;

assign c = u & v;

// integer i;
// always @(*) begin
//     for (i = 0; i < VEC_LEN - 1; i = i + 1) begin
//         if (i == 0) sum[i] <= c[i] + c[i + 1];
//         else sum[i] <= sum[i - 1] + c[i + 1];
//     end
// end

adder_tree #(
        .NUM_INPUTS(VEC_LEN)
    ) adders (
        .CLK(CLK),
        .nRST(nRST),
        .inputs(c),
        .sum(sum[(COUNTER_SIZE-2):0])
    );
assign sum[COUNTER_SIZE - 1] = 1'b0;

assign new_counter = counter + sum;
assign y = (new_counter >= $signed({{(COUNTER_SIZE - 1){1'b0}}, 1'b1})) ? 1'b1 : 1'b0;

always @(posedge CLK) begin
    if (!nRST) counter <= {COUNTER_SIZE{1'b0}};
    else counter <= next_counter;
end

always @(new_counter, y) begin
    next_counter <= new_counter - y;
end

endmodule
