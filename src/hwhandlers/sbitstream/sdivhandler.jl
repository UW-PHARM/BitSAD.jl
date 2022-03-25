struct SDivHandler end

gethandler(::Bool, ::Type{typeof(/)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) = SDivHandler()
init_state(::SDivHandler) = (id = 0,)

function (handler::SDivHandler)(buffer, netlist, state, inputs, outputs)
    # compute broadcast naming
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # add internal nets to netlist
    push!(netlist, Net(name = "div$(state.id)_out_pp", size = outsize))
    push!(netlist, Net(name = "div$(state.id)_out_mp", size = outsize))

    write(buffer, """
        // BEGIN div$(state.id)
        stoch_div_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(state.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_p"))),
                .Y(div$(state.id)_out_pp)
            );
        stoch_div_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(state.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_p"))),
                .Y(div$(state.id)_out_mp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(state.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(div$(state.id)_out_pp),
                .B(div$(state.id)_out_mp),
                .Y($(name(outputs[1]))_p)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(state.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(div$(state.id)_out_mp),
                .B(div$(state.id)_out_pp),
                .Y($(name(outputs[1]))_m)
            );
        // END div$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
