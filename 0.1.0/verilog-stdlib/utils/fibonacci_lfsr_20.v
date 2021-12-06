`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 12/05/2021
// Module Name: fibonacci_lfsr_20
// Description: 
//  Generates a pseudorandom 20-bit integer using a Fibonacci LFSR.
//  https://www.xilinx.com/support/documentation/application_notes/xapp052.pdf 
//////////////////////////////////////////////////////////////////////////////////
module fibonacci_lfsr_20(CLK, nRST, r);

// parameters
parameter SEED = 20'hDEADBEEF;

// I/O
input CLK, nRST;
output reg [19:0] r;

// internal wires
reg [19:0] shift_reg, next_shift_reg;
reg [19:0] next_r;
wire shift_in;

assign shift_in = shift_reg[19] ^ shift_reg[16];

always @(posedge CLK) begin
    if (!nRST) begin
        shift_reg <= SEED;
        r <= 20'd0;
    end
    else begin
        shift_reg <= next_shift_reg;
        r <= next_r;
    end
end

always @(shift_reg) begin
    next_shift_reg <= {shift_reg[18:0], shift_in};
    next_r <= {r[18:0], shift_reg[19]};
end

endmodule
