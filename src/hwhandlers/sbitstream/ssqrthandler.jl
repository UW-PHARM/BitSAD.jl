struct SSqrtHandler end

gethandler(broadcasted, ::Type{typeof(sqrt)}, ::Type{<:SBitstreamLike}) =
    !broadcasted ? SSqrtHandler() : error("Cannot generate hardware for broadcasted sqrt.")
init_state(::SSqrtHandler) = (id = 0,)

function (handler::SSqrtHandler)(buffer, netlist, state, inputs, outputs)
    write(buffer, """
        // BEGIN sqrt$(state.id)
        stoch_square_root sqrt$(state.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(name(inputs[1]))_p),
                .un   ($(name(inputs[2]))_m),
                .y    ($(name(outputs[1]))_p)
            );
        assign $(name(outputs[1]))_m = 1'b0;
        // END sqrt$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
