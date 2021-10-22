@kwdef mutable struct SL2NormHandler
    id = 0
end

gethandler(::Type{typeof(LinearAlgebra.norm)}, ::Type{<:AbstractVector{<:SBitstream}}) =
    SL2NormHandler()

function (handler::SL2NormHandler)(buffer, netlist, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    write(buffer, """
        $stdcomment
        // BEGIN l2norm$(handler.id)
        stoch_l2_norm #(
                .COUNTER_SIZE(8),
                .VEC_LEN($(netsize(inputs[1])[1]))
            ) l2norm$(handler.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(name(inputs[1]))_p),
                .un   ($(name(inputs[1]))_m),
                .y    ($(name(outputs[1]))_p)
            );
        assign $(name(outputs[1]))_m = 1'b0;
        // END l2norm$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end
