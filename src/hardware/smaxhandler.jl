@kwdef mutable struct SMaxHandler{N}
    id::Int = 0
    broadcasted::Bool
end

gethandler(broadcasted,
           ::Type{typeof(max)},
           x::Type{<:SBitstreamLike},
           y::Type{<:SBitstreamLike},
           zs::Type{<:SBitstreamLike}...) =
    SMaxHandler{length(zs) + 2}(broadcasted = broadcasted)

function (handler::SMaxHandler{N})(buffer, netlist, inputs, outputs) where N
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
        push!(netlist, Net(name = "max_bcast$(handler.id)_inputs", size = (N, netsize(outputs[1])...), signed = true))
        write(buffer, """
            $stdcomment
            // BEGIN max_bcast$(handler.id)
            genvar max$(handler.id)_i;

            generate
            for (max$(handler.id)_i = 0; max$(handler.id) < $num_elements; max$(handler.id)_i = max$(handler.id)_i + 1) begin : max$(handler.id)_gen
                assign max_bcast$(handler.id)_inputs_p[((max$(handler.id)_i + 1)*$N - 1) -: $N] = {$(join(map(fname -> fname("_p"), names), "[max$(handler.id)_i], "))[max$(handler.id)_i]};
                assign max_bcast$(handler.id)_inputs_m[((max$(handler.id)_i + 1)*$N - 1) -: $N] = {$(join(map(fname -> fname("_m"), names), "[max$(handler.id)_i], "))[max$(handler.id)_i]};

                stoch_signed_nmax #(
                    .COUNTER_SIZE(8),
                    .NUM_INPUTS($N)
                ) max_bcast$(handler.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .as_p(max_bcast$(handler.id)_inputs_p[((max$(handler.id)_i + 1)*$N - 1) -: $N]),
                    .as_m(max_bcast$(handler.id)_inputs_m[((max$(handler.id)_i + 1)*$N - 1) -: $N]),
                    .y_p($(name(outputs[1]))_p[max$(handler.id)_i]),
                    .y_m($(name(outputs[1]))_m[max$(handler.id)_i])
                );
            end
            endgenerate
            // END max_bcast$(handler.id)
            \n""")
    else
        push!(netlist, Net(name = "max$(handler.id)_inputs", size = (N, 1), signed = true))
        write(buffer, """
            $stdcomment
            // BEGIN max$(handler.id)
            """)
        write(buffer, "assign max$(handler.id)_inputs_p = {")
        write(buffer, join(map(fname -> fname("_p"), names), ", "))
        write(buffer, "};\n")
        write(buffer, "assign max$(handler.id)_inputs_m = {")
        write(buffer, join(map(fname -> fname("_m"), names), ", "))
        write(buffer, "};\n")
        write(buffer, """
            stoch_signed_nmax #(
                    .COUNTER_SIZE(8),
                    .NUM_INPUTS($N)
                ) max$(handler.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .as_p(max$(handler.id)_inputs_p),
                    .as_m(max$(handler.id)_inputs_m),
                    .y_p($(name(outputs[1]))_p),
                    .y_m($(name(outputs[1]))_m)
                );
            // END max$(handler.id)
            \n""")
    end

    handler.id += 1

    return buffer
end
