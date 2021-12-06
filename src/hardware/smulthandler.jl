struct SMultHandler end

struct SMatMultHandler end

gethandler(::Bool, ::Type{typeof(*)}, ::Type{<:SBitstream}, ::Type{<:SBitstream}) = SMultHandler()
init_state(::SMultHandler) = (id = 0,)

gethandler(broadcasted::Bool,
           ::Type{typeof(*)},
           ::Type{<:AbstractArray{<:SBitstream}},
           ::Type{<:AbstractArray{<:SBitstream}}) =
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

    # add internal nets to netlist
    push!(netlist, Net(name = "mult$(state.id)_out_pp", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_pm", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_mp", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_mm", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_11", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_12", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_13", size = outsize))
    push!(netlist, Net(name = "mult$(state.id)_out_14", size = outsize))

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    write(buffer, """
        $stdcomment
        // BEGIN mult$(state.id)
        assign mult$(state.id)_out_pp = $(lname("_p")) & $(rname("_p"))
        assign mult$(state.id)_out_pm = $(lname("_p")) & $(rname("_m"))
        assign mult$(state.id)_out_mp = $(lname("_m")) & $(rname("_p"))
        assign mult$(state.id)_out_mm = $(lname("_m")) & $(rname("_m"))
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(state.id)_11 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(state.id)_out_pp),
                .B(mult$(state.id)_out_pm),
                .Y(mult$(state.id)_out_11)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(state.id)_12 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(state.id)_out_pm),
                .B(mult$(state.id)_out_pp),
                .Y(mult$(state.id)_out_12)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(state.id)_13 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(state.id)_out_mp),
                .B(mult$(state.id)_out_mm),
                .Y(mult$(state.id)_out_13)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(state.id)_14 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(state.id)_out_mm),
                .B(mult$(state.id)_out_mp),
                .Y(mult$(state.id)_out_14)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(state.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(state.id)_out_11),
                .B(mult$(state.id)_out_14),
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(state.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(state.id)_out_12),
                .B(mult$(state.id)_out_13),
                .Y($(name(outputs[1]))_m)
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

    # add internal nets to netlist
    push!(netlist, Net(name = "mmult$(state.id)_out_pp", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_pm", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_mp", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_mm", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_11", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_12", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_13", size = outsize))
    push!(netlist, Net(name = "mmult$(state.id)_out_14", size = outsize))

    write(buffer, """
        $stdcomment
        // BEGIN mmult$(state.id)
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(state.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_p),
                .B($(name(inputs[2]))_p),
                .Y(mmult$(state.id)_out_pp)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(state.id)_pm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_p),
                .B($(name(inputs[2]))_m),
                .Y(mmult$(state.id)_out_pm)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(state.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .B($(name(inputs[2]))_p),
                .Y(mmult$(state.id)_out_mp)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(state.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .B($(name(inputs[2]))_m),
                .Y(mmult$(state.id)_out_mm)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(state.id)_11 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(state.id)_out_pp),
                .B(mmult$(state.id)_out_pm),
                .Y(mmult$(state.id)_out_11)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(state.id)_12 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(state.id)_out_pm),
                .B(mmult$(state.id)_out_pp),
                .Y(mmult$(state.id)_out_12)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(state.id)_13 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(state.id)_out_mp),
                .B(mmult$(state.id)_out_mm),
                .Y(mmult$(state.id)_out_13)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(state.id)_14 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(state.id)_out_mm),
                .B(mmult$(state.id)_out_mp),
                .Y(mmult$(state.id)_out_14)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(state.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(state.id)_out_11),
                .B(mmult$(state.id)_out_14),
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(state.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(state.id)_out_12),
                .B(mmult$(state.id)_out_13),
                .Y($(name(outputs[1]))_m)
            );
        // END mmult$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end