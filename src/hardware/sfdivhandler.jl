@kwdef mutable struct SFixedGainDivHandler
    id::Int = 0
    broadcasted::Bool
end

gethandler(broadcasted, ::Type{typeof(÷)}, ::Type{<:SBitstreamLike}, ::Type{<:Real}) =
    SFixedGainDivHandler(broadcasted = broadcasted)

function (handler::SFixedGainDivHandler)(buffer, netlist, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)

    # compute output size
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    broadcast = handler.broadcasted ? "_bcast" : ""
    write(buffer, """
        $stdcomment
        // BEGIN fdiv$(broadcast)$(handler.id)
        stoch_fixed_gain_div_mat #(
                .COUNTER_SIZE(8),
                .GAIN($(name(inputs[2]))),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(broadcast)$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_p),
                .Y($(name(outputs[1]))_p)
            );
        stoch_fixed_gain_div_mat #(
                .COUNTER_SIZE(8),
                .GAIN($(name(inputs[2]))),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(broadcast)$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .Y($(name(outputs[1]))_m)
            );
        // END fdiv$(broadcast)$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end
