struct SL2NormHandler end

gethandler(broadcasted, ::Type{typeof(LinearAlgebra.norm)}, ::Type{<:AbstractVector{<:SBitstream}}) =
    !broadcasted ? SL2NormHandler() :
                   error("Cannot generate hardware for broadcasted L2 norm.")
init_state(::SL2NormHandler) = (id = 0,)

function (handler::SL2NormHandler)(buffer, netlist, state, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    write(buffer, """
        $stdcomment
        // BEGIN l2norm$(state.id)
        stoch_l2_norm #(
                .COUNTER_SIZE(8),
                .VEC_LEN($(netsize(inputs[1])[1]))
            ) l2norm$(state.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(name(inputs[1]))_p),
                .un   ($(name(inputs[1]))_m),
                .y    ($(name(outputs[1]))_p)
            );
        assign $(name(outputs[1]))_m = 1'b0;
        // END l2norm$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
