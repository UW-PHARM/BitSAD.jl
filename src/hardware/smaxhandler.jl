struct SMaxHandler{N} end

gethandler(::Bool,
           ::Type{typeof(max)},
           x::Type{<:SBitstreamLike},
           y::Type{<:SBitstreamLike},
           zs::Type{<:SBitstreamLike}...) =
    SMaxHandler{length(zs) + 2}()
init_state(::SMaxHandler) = (id = 0,)

function (handler::SMaxHandler{N})(buffer, netlist, state, inputs, outputs) where N
    @assert length(inputs) == N "Cannot apply SMaxHandler{$N} to length(inputs) == $(length(inputs))"

    # update netlist with inputs
    foreach(inputs) do input
        setsigned!(netlist, input, true)
    end

    # compute broadcast naming
    names = handle_broadcast_name(name.(inputs), netsize.(inputs), netsize(outputs[1]))

    # update netlist with output
    setsigned!(netlist, outputs[1], true)

    if handler.broadcasted
        num_elements = join(netsize(outputs[1]), "*")
        push!(netlist, Net(name = "max_$(N)_$(state.id)_inputs", size = (N, netsize(outputs[1])...), signed = true))
        write(buffer, """
            $stdcomment
            // BEGIN max_$(N)_$(state.id)
            genvar max_$(N)_$(state.id)_i;

            generate
            for (max_$(N)_$(state.id)_i = 0; max_$(N)_$(state.id) < $num_elements; max_$(N)_$(state.id)_i = max_$(N)_$(state.id)_i + 1) begin : max_$(N)_$(state.id)_gen
                assign max_$(N)_$(state.id)_inputs_p[((max_$(N)_$(state.id)_i + 1)*$N - 1) -: $N] = {$(join(map(fname -> fname("_p"), names), "[max_$(N)_$(state.id)_i], "))[max_$(N)_$(state.id)_i]};
                assign max_$(N)_$(state.id)_inputs_m[((max_$(N)_$(state.id)_i + 1)*$N - 1) -: $N] = {$(join(map(fname -> fname("_m"), names), "[max_$(N)_$(state.id)_i], "))[max_$(N)_$(state.id)_i]};

                stoch_signed_nmax #(
                    .COUNTER_SIZE(8),
                    .NUM_INPUTS($N)
                ) max_$(N)_$(state.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .as_p(max_$(N)_$(state.id)_inputs_p[((max_$(N)_$(state.id)_i + 1)*$N - 1) -: $N]),
                    .as_m(max_$(N)_$(state.id)_inputs_m[((max_$(N)_$(state.id)_i + 1)*$N - 1) -: $N]),
                    .y_p($(name(outputs[1]))_p[max_$(N)_$(state.id)_i]),
                    .y_m($(name(outputs[1]))_m[max_$(N)_$(state.id)_i])
                );
            end
            endgenerate
            // END max_$(N)_$(state.id)
            \n""")
    else
        push!(netlist, Net(name = "max_$(N)_$(state.id)_inputs", size = (N, 1), signed = true))
        write(buffer, """
            $stdcomment
            // BEGIN max_$(N)_$(state.id)
            """)
        write(buffer, "assign max_$(N)_$(state.id)_inputs_p = {")
        write(buffer, join(map(fname -> fname("_p"), names), ", "))
        write(buffer, "};\n")
        write(buffer, "assign max_$(N)_$(state.id)_inputs_m = {")
        write(buffer, join(map(fname -> fname("_m"), names), ", "))
        write(buffer, "};\n")
        write(buffer, """
            stoch_signed_nmax #(
                    .COUNTER_SIZE(8),
                    .NUM_INPUTS($N)
                ) max_$(N)_$(state.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .as_p(max_$(N)_$(state.id)_inputs_p),
                    .as_m(max_$(N)_$(state.id)_inputs_m),
                    .y_p($(name(outputs[1]))_p),
                    .y_m($(name(outputs[1]))_m)
                );
            // END max_$(N)_$(state.id)
            \n""")
    end

    return buffer, (id = state.id + 1,)
end
