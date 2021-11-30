@kwdef mutable struct SAddHandler
    id::Int = 0
    broadcasted::Bool
end

gethandler(broadcasted, ::Type{typeof(+)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) =
    SAddHandler(broadcasted = broadcasted)

function (handler::SAddHandler)(buffer, netlist, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output naming
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # update netlist with output
    setsigned!(netlist, outputs[1], true)

    broadcast = handler.broadcasted ? "_bcast" : ""
    write(buffer, """
        $stdcomment
        // BEGIN add$(broadcast)$(handler.id)
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(broadcast)$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_p"))),
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(broadcast)$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_m"))),
                .Y($(name(outputs[1]))_m)
            );
        // END add$(broadcast)$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end
