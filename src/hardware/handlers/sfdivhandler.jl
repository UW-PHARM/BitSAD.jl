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
                                         outputs::Vector{Variable})
    # update netlist with inputs
    setsigned!(netlist, getname(inputs[1]), true)

    # compute output size
    outsize = getsize(netlist, getname(outputs[1]))

    # add output net to netlist
    setsigned!(netlist, getname(outputs[1]), true)

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

allowconstreplace(::Type{SFixedGainDivHandler}) = false