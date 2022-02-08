`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: PHARM
// Engineer: Kyle Daruwalla
// 
// Create Date: 02/04/2022
// Module Name: adder_tree
// Description:
//  A simple N 1-bit input adder tree.
//////////////////////////////////////////////////////////////////////////////////
module adder_tree #(
    parameter NUM_INPUTS = 200,
    localparam SUM_WIDTH = $clog2(NUM_INPUTS) + 1
) (
    input logic CLK,
    input logic nRST,
    input logic [(NUM_INPUTS-1):0] inputs,
    output logic [(SUM_WIDTH-1):0] sum
);

localparam integer NUM_128 = NUM_INPUTS / 128;
localparam integer NUM_128_REM = NUM_INPUTS - NUM_128 * 128;

logic [(NUM_128-1):0][7:0] sum128;
logic [NUM_128:0][(SUM_WIDTH-1):0] sum128_reduce;

genvar i128;
generate
for (i128 = 1; i128 <= NUM_128; i128 = i128 + 1) begin : blk128_gen
    adder_tree_128 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(127 * i128) -: 128]),
            .sum(sum128[i128 - 1])
        );
end
endgenerate

integer i128_reduce;
assign sum128_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum128) begin
    for (i128_reduce = 1; i128_reduce <= NUM_128; i128_reduce = i128_reduce + 1) begin
        sum128_reduce[i128_reduce] <= sum128_reduce[i128_reduce - 1] + sum128[i128_reduce - 1];
    end
end

localparam integer NUM_64 = NUM_128_REM / 64;
localparam integer NUM_64_REM = NUM_128_REM - NUM_64 * 64;

logic [(NUM_64-1):0][6:0] sum64;
logic [NUM_64:0][(SUM_WIDTH-1):0] sum64_reduce;

genvar i64;
generate
for (i64 = 1; i64 <= NUM_64; i64 = i64 + 1) begin : blk64_gen
    adder_tree_64 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(63 * i64) -: 64]),
            .sum(sum64[i64 - 1])
        );
end
endgenerate

integer i64_reduce;
assign sum64_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum64) begin
    for (i64_reduce = 1; i64_reduce <= NUM_64; i64_reduce = i64_reduce + 1) begin
        sum64_reduce[i64_reduce] <= sum64_reduce[i64_reduce - 1] + sum64[i64_reduce - 1];
    end
end

localparam integer NUM_32 = NUM_64_REM / 32;
localparam integer NUM_32_REM = NUM_64_REM - NUM_32 * 32;

logic [(NUM_32-1):0][5:0] sum32;
logic [NUM_32:0][(SUM_WIDTH-1):0] sum32_reduce;

genvar i32;
generate
for (i32 = 1; i32 <= NUM_32; i32 = i32 + 1) begin : blk32_gen
    adder_tree_32 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(31 * i32) -: 32]),
            .sum(sum32[i32 - 1])
        );
end
endgenerate

integer i32_reduce;
assign sum32_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum32) begin
    for (i32_reduce = 1; i32_reduce <= NUM_32; i32_reduce = i32_reduce + 1) begin
        sum32_reduce[i32_reduce] <= sum32_reduce[i32_reduce - 1] + sum32[i32_reduce - 1];
    end
end

localparam integer NUM_16 = NUM_32_REM / 16;
localparam integer NUM_16_REM = NUM_32_REM - NUM_16 * 16;

logic [(NUM_16-1):0][4:0] sum16;
logic [NUM_16:0][(SUM_WIDTH-1):0] sum16_reduce;

genvar i16;
generate
for (i16 = 1; i16 <= NUM_16; i16 = i16 + 1) begin : blk16_gen
    adder_tree_16 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(15 * i16) -: 16]),
            .sum(sum16[i16 - 1])
        );
end
endgenerate

integer i16_reduce;
assign sum16_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum16) begin
    for (i16_reduce = 1; i16_reduce <= NUM_16; i16_reduce = i16_reduce + 1) begin
        sum16_reduce[i16_reduce] <= sum16_reduce[i16_reduce - 1] + sum16[i16_reduce - 1];
    end
end

localparam integer NUM_8 = NUM_16_REM / 8;
localparam integer NUM_8_REM = NUM_16_REM - NUM_8 * 8;

logic [(NUM_8-1):0][3:0] sum8;
logic [NUM_8:0][(SUM_WIDTH-1):0] sum8_reduce;

genvar i8;
generate
for (i8 = 1; i8 <= NUM_8; i8 = i8 + 1) begin : blk8_gen
    adder_tree_8 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(7 * i8) -: 8]),
            .sum(sum8[i8 - 1])
        );
end
endgenerate

integer i8_reduce;
assign sum8_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum8) begin
    for (i8_reduce = 1; i8_reduce <= NUM_8; i8_reduce = i8_reduce + 1) begin
        sum8_reduce[i8_reduce] <= sum8_reduce[i8_reduce - 1] + sum8[i8_reduce - 1];
    end
end

localparam integer NUM_4 = NUM_8_REM / 4;
localparam integer NUM_4_REM = NUM_8_REM - NUM_4 * 4;

logic [(NUM_4-1):0][2:0] sum4;
logic [NUM_4:0][(SUM_WIDTH-1):0] sum4_reduce;

genvar i4;
generate
for (i4 = 1; i4 <= NUM_4; i4 = i4 + 1) begin : blk4_gen
    adder_tree_4 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(3 * i4) -: 4]),
            .sum(sum4[i4 - 1])
        );
end
endgenerate

integer i4_reduce;
assign sum4_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum4) begin
    for (i4_reduce = 1; i4_reduce <= NUM_4; i4_reduce = i4_reduce + 1) begin
        sum4_reduce[i4_reduce] <= sum4_reduce[i4_reduce - 1] + sum4[i4_reduce - 1];
    end
end

localparam integer NUM_2 = NUM_4_REM / 2;
localparam integer NUM_2_REM = NUM_4_REM - NUM_2 * 2;

logic [(NUM_2-1):0][1:0] sum2;
logic [NUM_2:0][(SUM_WIDTH-1):0] sum2_reduce;

genvar i2;
generate
for (i2 = 1; i2 <= NUM_2; i2 = i2 + 1) begin : blk2_gen
    adder_tree_2 adder (
            .CLK(CLK),
            .nRST(nRST),
            .inputs(inputs[(1 * i2) -: 2]),
            .sum(sum2[i2 - 1])
        );
end
endgenerate

integer i2_reduce;
assign sum2_reduce[0] = {SUM_WIDTH{1'b0}};
always @(sum2) begin
    for (i2_reduce = 1; i2_reduce <= NUM_2; i2_reduce = i2_reduce + 1) begin
        sum2_reduce[i2_reduce] <= sum2_reduce[i2_reduce - 1] + sum2[i2_reduce - 1];
    end
end

assign sum = sum128_reduce[NUM_128] +
             sum64_reduce[NUM_64] +
             sum32_reduce[NUM_32] +
             sum16_reduce[NUM_16] +
             sum8_reduce[NUM_8] +
             sum4_reduce[NUM_4] +
             sum2_reduce[NUM_2];

endmodule
