struct SAddHandler end

gethandler(::Bool, ::Type{typeof(+)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) = SAddHandler()
init_state(::SAddHandler) = (id = 0,)

function (handler::SAddHandler)(buffer, netlist, state, inputs, outputs)
    # compute broadcast naming
    lname, rname = handle_broadcast_name(name.(inputs), netsize.(inputs), netsize(outputs[1]))

    # add broadcast signals
    push!(netlist, Net(name = "add$(state.id)_$(name(inputs[1]))_bcast",
                       size = netsize(outputs[1]),
                       suffixes = ["_p", "_m"]))
    push!(netlist, Net(name = "add$(state.id)_$(name(inputs[2]))_bcast",
                       size = netsize(outputs[1]),
                       signed = ["_p", "_m"]))

    outsize = netsize(outputs[1])
    write(buffer, """
        // BEGIN add$(state.id)
        """)
    write(buffer, """
        assign add$(state.id)_$(name(inputs[1]))_bcast_p = $(lname("_p"));
        assign add$(state.id)_$(name(inputs[1]))_bcast_m = $(lname("_m"));
        assign add$(state.id)_$(name(inputs[2]))_bcast_p = $(rname("_p"));
        assign add$(state.id)_$(name(inputs[2]))_bcast_m = $(rname("_m"));
        """)
    write_bcast_instantiation(buffer, "add$(state.id)", outsize, """
        stoch_add add$(state.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .a(add$(state.id)_$(name(inputs[1]))_bcast_p[add$(state.id)_i]),
                .b(add$(state.id)_$(name(inputs[2]))_bcast_p[add$(state.id)_i]),
                .y($(name(outputs[1]))_p[add$(state.id)_i])
            );
        stoch_add add$(state.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .a(add$(state.id)_$(name(inputs[1]))_bcast_m[add$(state.id)_i]),
                .b(add$(state.id)_$(name(inputs[2]))_bcast_m[add$(state.id)_i]),
                .y($(name(outputs[1]))_m[add$(state.id)_i])
            );""")
    write(buffer, """
            // END add$(state.id)
            \n""")

    return buffer, (id = state.id + 1,)
end
