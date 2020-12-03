@kwdef mutable struct SSqrtHandler <: AbstractHandler
    id = 0
end

gethandler(::Type{typeof(sqrt)}, ::Type{<:SBitstreamLike}) = SSqrtHandler()

function (handler::SSqrtHandler)(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
    # compute output size
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    outstring = """
        $stdcomment
        // BEGIN sqrt$(handler.id)
        stoch_square_root #(
                .COUNTER_SIZE(10)
            ) sqrt$(handler.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(name(inputs[1]))_p),
                .un   ($(name(inputs[2]))_m),
                .y    ($(name(outputs[1]))_p)
            );
        assign $(name(outputs[1]))_m = 1'b0;
        // END sqrt$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end