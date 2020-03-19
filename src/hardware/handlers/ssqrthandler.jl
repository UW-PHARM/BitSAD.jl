@kwdef mutable struct SSqrtHandler <: AbstractHandler
    id = 0
end

@register(SSqrtHandler, sqrt, begin
    [SBit] => [SBit]
    [Vector{SBit}] => [Vector{SBit}]
    [Matrix{SBit}] => [Matrix{SBit}]
end)

function (handler::SSqrtHandler)(netlist::Netlist,
                                 inputs::Vector{Variable},
                                 outputs::Vector{Variable})
    # compute output size
    outsize = getsize(netlist, getname(outputs[1]))

    # add output net to netlist
    setsigned!(netlist, getname(outputs[1]), true)

    outstring = """
        $stdcomment
        // BEGIN sqrt$(handler.id)
        stoch_square_root #(
                .COUNTER_SIZE(10)
            ) sqrt$(handler.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(inputs[1].name)_p),
                .un   ($(inputs[2].name)_m),
                .y    ($(outputs[1].name)_p)
            );
        assign $(outputs[1].name)_m = 1'b0;
        // END sqrt$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end