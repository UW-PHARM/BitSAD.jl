@kwdef mutable struct SFixedGainDivHandler <: AbstractHandler
    id = 0
end

istraceprimitive(::typeof(÷), ::SBitstreamLike, ::Real) = true
gethandler(::Type{typeof(÷)}, ::Type{<:SBitstreamLike}, ::Type{<:Real}) = SFixedGainDivHandler()

function (handler::SFixedGainDivHandler)(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)

    # compute output size
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    outstring = """
        $stdcomment
        // BEGIN fdiv$(handler.id)
        stoch_fixed_gain_div_mat #(
                .COUNTER_SIZE(8),
                .GAIN($(name(inputs[2]))),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) fdiv$(handler.id)_p (
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
            ) fdiv$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .Y($(name(outputs[1]))_m)
            );
        // END fdiv$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

allowconstreplace(::Type{SFixedGainDivHandler}) = false