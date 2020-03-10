@kwdef mutable struct SL2NormHandler <: AbstractHandler
    id = 0
end

register(Operation([Symbol("Vector{SBit}")], [Symbol("SBit")], :norm), SL2NormHandler)

function (handler::SL2NormHandler)(netlist::Netlist,
                                   inputs::Vector{Variable},
                                   outputs::Vector{Variable},
                                   sizes::Vector{Tuple{Int, Int}})
    # compute output size
    outsize = (1, 1)

    # add output net to netlist
    update!(netlist, Net(name = string(outputs[1].name), signed = true, size = outsize))

    outstring = """
        $stdcomment
        // BEGIN l2norm$(handler.id)
        stoch_l2_norm #(
                .COUNTER_SIZE(8),
                .VEC_LEN($(sizes[1][1]))
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