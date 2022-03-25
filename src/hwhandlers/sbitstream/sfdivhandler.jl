struct SFixedGainDivHandler end

gethandler(::Bool, ::Type{typeof(÷)}, ::Type{<:SBitstreamLike}, ::Type{<:Real}) = SFixedGainDivHandler()
init_state(::SFixedGainDivHandler) = (id = 0,)

function (handler::SFixedGainDivHandler)(buffer, netlist, state, inputs, outputs)
    # compute output size
    outsize = netsize(outputs[1])

    write(buffer, """
        // BEGIN fdiv$(state.id)
        stoch_fixed_gain_div_mat #(
                .GAIN($(name(inputs[2]))),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(state.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_p),
                .Y($(name(outputs[1]))_p)
            );
        stoch_fixed_gain_div_mat #(
                .GAIN($(name(inputs[2]))),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(state.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .Y($(name(outputs[1]))_m)
            );
        // END fdiv$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
