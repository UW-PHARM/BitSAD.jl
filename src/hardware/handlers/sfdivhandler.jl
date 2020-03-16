@kwdef mutable struct SFixedGainDivHandler <: AbstractHandler
    id = 0
end

@register(SFixedGainDivHandler, ÷, begin
    [SBit, Number] => [SBit]
    [Vector{SBit}, Number] => [Vector{SBit}]
    [Matrix{SBit}, Number] => [Matrix{SBit}]
end)

function (handler::SFixedGainDivHandler)(netlist::Netlist,
                                         inputs::Vector{Variable},
                                         outputs::Vector{Variable},
                                         sizes::Vector{Tuple{Int, Int}})
    # compute output size
    outsize = sizes[1]

    # add output net to netlist
    update!(netlist, Net(name = string(outputs[1].name), signed = true, size = outsize))

    outstring = """
        $stdcomment
        // BEGIN fdiv$(handler.id)
        stoch_fixed_gain_div_mat #(
                .COUNTER_SIZE(8),
                .GAIN($(inputs[2].name)),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_p),
                .Y($(outputs[1].name)_p)
            );
        stoch_fixed_gain_div_mat #(
                .COUNTER_SIZE(8),
                .GAIN($(inputs[2].name)),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_m),
                .Y($(outputs[1].name)_m)
            );
        // END fdiv$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end