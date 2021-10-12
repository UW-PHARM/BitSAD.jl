@kwdef mutable struct SBitstreamHandler
    id = 0
end

BitSAD.is_hardware_primitive(::Type{typeof(SBitstream)}, ::Type{<:SBitstream}) = true
BitSAD.is_hardware_primitive(::Type{typeof(Base.broadcasted)},
                             ::Type{typeof(SBitstream)},
                             ::Type{<:SBitstreamLike}) = true
gethandler(::Bool, ::Type{typeof(SBitstream)}, ::Type{<:Real}) = SBitstreamHandler()
gethandler(::Bool, ::Type{typeof(SBitstream)}, ::Type{<:AbstractArray{<:Real}}) = SBitstreamHandler()

function (handler::SBitstreamHandler)(buffer, netlist, inputs, outputs)
    # set output as signed
    setsigned!(netlist, outputs[1], true)

    num_elements = prod(netsize(outputs[1]))

    # value
    if num_elements > 1
        val = lstrip.(name(inputs[1]), '-')
        isneg = value(inputs[1]) .>= 0
    else
        val = [lstrip(name(inputs[1]), '-')]
        isneg = [value(inputs[1]) >= 0]
    end

    write(buffer, """
        // BEGIN bitstream_rng$(handler.id)
        """)
    for i in 1:num_elements
        idx_string = (num_elements > 1) ? "[$(i - 1)]" : ""
        write(buffer, """
            bitstream_rng #(
                    .VALUE($(val[i])),
                    .IS_NEGATIVE($(isneg[i]))
                ) bitstream_rng$(handler.id)_$i (
                    .CLK(CLK),
                    .nRST(nRST),
                    .out_p($(name(outputs[1]))_p$idx_string),
                    .out_m($(name(outputs[1]))_m$idx_string)
                );
            """)
    end
    write(buffer, """
        // END bitstream_rng$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end
