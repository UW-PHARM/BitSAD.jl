@kwdef mutable struct SL2NormHandler <: AbstractHandler
    id = 0
end

@register(SL2NormHandler, norm, [Vector{SBit}] => [SBit])

function (handler::SL2NormHandler)(netlist::Netlist,
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
        // BEGIN l2norm$(handler.id)
        stoch_l2_norm #(
                .COUNTER_SIZE(8),
                .VEC_LEN($(getsize(netlist, getname(inputs[1]))[1]))
            ) l2norm$(handler.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(inputs[1].name)_p),
                .un   ($(inputs[1].name)_m),
                .y    ($(outputs[1].name)_p)
            );
        assign $(outputs[1].name)_m = 1'b0;
        // END l2norm$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end