struct SMultHandler end

struct SMatMultHandler end

gethandler(::Bool, ::Type{typeof(*)}, ::Type{<:SBitstream}, ::Type{<:SBitstream}) = SMultHandler()
init_state(::SMultHandler) = (id = 0,)

gethandler(broadcasted::Bool,
           ::Type{typeof(*)},
           ::Type{<:AbstractArray{<:SBitstream, 2}},
           ::Type{<:AbstractArray{<:SBitstream, 2}}) =
    broadcasted ? SMultHandler() : SMatMultHandler()
init_state(::SMatMultHandler) = (id = 0,)

function (handler::SMultHandler)(buffer, netlist, state, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output size
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    write(buffer, """
        $stdcomment
        // BEGIN mult$(state.id)
        stoch_signed_elem_mult_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COL($(outsize[2]))
            ) mult$(state.id) (
                .CLK(CLK),
                .nRST(nRST),
                .A_p($(lname("_p"))),
                .A_m($(lname("_m"))),
                .B_p($(rname("_p"))),
                .B_m($(rname("_m"))),
                .Y_p($(name(outputs[1]))_p),
                .Y_m($(name(outputs[1]))_m)
            );
        // END mult$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end

function (handler::SMatMultHandler)(buffer, netlist, state, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output size
    m, n = netsize(inputs[1])
    _, p = netsize(inputs[2])
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    write(buffer, """
        $stdcomment
        // BEGIN mmult$(state.id)
        stoch_signed_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(state.id) (
                .CLK(CLK),
                .nRST(nRST),
                .A_p($(name(inputs[1]))_p),
                .A_m($(name(inputs[1]))_m),
                .B_p($(name(inputs[2]))_p),
                .B_m($(name(inputs[2]))_m),
                .Y_p($(name(outputs[1]))_p),
                .Y_m($(name(outputs[1]))_m)
            );
        // END mmult$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end