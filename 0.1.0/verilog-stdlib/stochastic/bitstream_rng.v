`timescale 1ns / 1ps

module bitstream_rng(CLK, nRST, out_p, out_m);

parameter BITWIDTH = 20;
parameter VALUE = {BITWIDTH{1'b0}};
parameter IS_NEGATIVE = 1'b0;

// we support 20 and 64 bit LFSRs
localparam _BITWIDTH = (BITWIDTH > 20) ? 64 : 20;
localparam _VALUE = {{(_BITWIDTH - BITWIDTH){1'b0}}, VALUE};

// I/O
input CLK, nRST;
output out_p, out_m;
wire [(_BITWIDTH - 1):0] lfsr_r;

generate
    if (_BITWIDTH == 20) begin
        fibonacci_lfsr_20 d_lfsr (
                .CLK(CLK),
                .nRST(nRST),
                .r(lfsr_r)
            );
    end
    else begin
        fibonacci_lfsr_64 d_lfsr (
                .CLK(CLK),
                .nRST(nRST),
                .r(lfsr_r)
            );
    end
endgenerate

assign out_p = ((lfsr_r < VALUE) && !IS_NEGATIVE) ? 1'b1 : 1'b0;
assign out_m = ((lfsr_r < VALUE) && IS_NEGATIVE) ? 1'b1 : 1'b0;

endmodule
