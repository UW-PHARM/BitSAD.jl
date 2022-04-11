`timescale 1ns / 1ps
/////////////////////////////////////////////////////////////////////////////////////
// PHARM
// Kyle Daruwalla
//
// sdm
//		SDM unit
/////////////////////////////////////////////////////////////////////////////////////
module sdm #(
    parameter BIT_WIDTH = 16,
    parameter INT_WIDTH = 1
) (
    input logic CLK,
    input logic nRST,
    input logic signed [(BIT_WIDTH-1):0] x,
    output logic y
);

// internal wires
logic signed [(BIT_WIDTH-1):0] y_new;
logic signed [(BIT_WIDTH-1):0] err;
logic signed [(BIT_WIDTH-1):0] err_next;

assign y = (x >= err) ? 1'b1 : 1'b0;
assign y_new = y ?
                 {{(INT_WIDTH-1){1'b0}}, 2'b01, {(BIT_WIDTH-INT_WIDTH-1){1'b0}}}
               : {{(INT_WIDTH-1){1'b1}}, 2'b11, {(BIT_WIDTH-INT_WIDTH-1){1'b0}}};

assign err_next = y_new - x + err;

always @(posedge CLK) begin
    if (!nRST) err <= {BIT_WIDTH{1'b0}};
    else err <= err_next;
end

endmodule
