@kwdef mutable struct SMaxHandler
    id::Int = 0
    broadcasted::Bool
end

gethandler(broadcasted, ::Type{typeof(max)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) =
    SMaxHandler(broadcasted = broadcasted)

function (handler::SMaxHandler)(buffer, netlist, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output naming
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))

    # update netlist with output
    setsigned!(netlist, outputs[1], true)

    if handler.broadcasted
        num_elements = join(netsize(outputs[1]), "*")
        write(buffer, """
            $stdcomment
            // BEGIN max$(handler.id)
            genvar max$(handler.id)_i;

            generate
            for (max$(handler.id)_i = 0; max$(handler.id) < $num_elements; max$(handler.id)_i = max$(handler.id)_i + 1) begin : max$(handler.id)_gen
                stoch_signed_max #(
                    .COUNTER_SIZE(8)
                ) max$(handler.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .a_p($(lname("_p"))[max$(handler.id)_i]),
                    .a_m($(lname("_m"))[max$(handler.id)_i]),
                    .b_p($(rname("_p"))[max$(handler.id)_i]),
                    .b_m($(rname("_m"))[max$(handler.id)_i]),
                    .y_p($(name(outputs[1]))_p[max$(handler.id)_i]),
                    .y_m($(name(outputs[1]))_m[max$(handler.id)_i])
                );
            end
            endgenerate
            // END max$(handler.id)
            \n""")
    else
        write(buffer, """
            $stdcomment
            // BEGIN max$(handler.id)
            stoch_signed_max #(
                    .COUNTER_SIZE(8)
                ) max$(handler.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .a_p($(lname("_p"))),
                    .a_m($(lname("_m"))),
                    .b_p($(rname("_p"))),
                    .b_m($(rname("_m"))),
                    .y_p($(name(outputs[1]))_p),
                    .y_m($(name(outputs[1]))_m)
                );
            // END max$(handler.id)
            \n""")
    end

    handler.id += 1

    return buffer
end
