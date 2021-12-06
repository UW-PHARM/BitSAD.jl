struct SBitstreamHandler end

is_hardware_primitive(::Type{typeof(SBitstream)}, ::Type{<:SBitstream}) = true
is_hardware_primitive(::Type{typeof(Base.broadcasted)}, ::Type{typeof(SBitstream)}, ::Type{<:SBitstreamLike}) = true
gethandler(::Bool, ::Type{typeof(SBitstream)}, ::Type{<:SBitstreamLike}) = SBitstreamHandler()
init_state(::SBitstreamHandler) = (id = 0,)

function (handler::SBitstreamHandler)(buffer, netlist, state, inputs, outputs)
    # set output as signed
    setsigned!(netlist, outputs[1], true)

    num_elements = join(netsize(outputs[1]), "*")

    # value
    if value(inputs[1]) isa AbstractArray
        val = lstrip.(name(inputs[1]), '-')
        isneg = Int.(value(inputs[1]) .< 0)
    else
        val = [lstrip(name(inputs[1]), '-')]
        isneg = [Int(value(inputs[1]) < 0)]
    end

    write(buffer, """
        // BEGIN bitstream_rng$(state.id)
        """)

    # create parameter if necessary
    if isparameter(inputs[1])
        input_string = name(inputs[1])
        input_size = bitwidth(inputs[1])
    else
        input_string = "bitstream_rng$(state.id)_value"
        input_size = bitwidth(inputs[1])

        write(buffer, "localparam $input_string = {")
        write(buffer, join(val, ", "))
        write(buffer, "};\n")
    end

    write(buffer, "localparam $(input_string)_isneg = $(length(isneg))'b")
    write(buffer, join(isneg, ""))
    write(buffer, ";\n")

    write(buffer, """
        genvar bitstream_rng$(state.id)_i;

        generate
        for (bitstream_rng$(state.id)_i = 0; bitstream_rng$(state.id)_i < $num_elements; bitstream_rng$(state.id)_i = bitstream_rng$(state.id)_i + 1) begin : bitstream_rng$(state.id)_gen
            bitstream_rng #(
                    .BITWIDTH($input_size),
                    .VALUE($input_string[bitstream_rng$(state.id)_i*$input_size +: $input_size]),
                    .IS_NEGATIVE($(input_string)_isneg[bitstream_rng$(state.id)_i])
                ) bitstream_rng$(state.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .out_p($(name(outputs[1]))_p[bitstream_rng$(state.id)_i]),
                    .out_m($(name(outputs[1]))_m[bitstream_rng$(state.id)_i])
                );
        end
        endgenerate
        // END bitstream_rng$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
