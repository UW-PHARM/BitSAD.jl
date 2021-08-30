@kwdef mutable struct SMultHandler
    id = 0
end

@kwdef mutable struct SMatMultHandler
    id = 0
end

gethandler(::Type{typeof(*)}, ::Type{<:SBitstream}, ::Type{<:SBitstream}) = SMultHandler()

gethandler(broadcasted::Bool,
           ::Type{typeof(*)},
           ::Type{<:AbstractArray{<:SBitstream}},
           ::Type{<:AbstractArray{<:SBitstream}}) =
    broadcasted ? SMultHandler() : SMatMultHandler()

function (handler::SMultHandler)(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output size
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # add internal nets to netlist
    push!(netlist, Net(name = "mult$(handler.id)_pp", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_pm", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_mp", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_mm", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_11", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_12", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_13", size = outsize))
    push!(netlist, Net(name = "mult$(handler.id)_14", size = outsize))

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    outstring = """
        $stdcomment
        // BEGIN mult$(handler.id)
        assign mult$(handler.id)_pp = $(lname("_p")) & $(rname("_p"))
        assign mult$(handler.id)_pm = $(lname("_p")) & $(rname("_m"))
        assign mult$(handler.id)_mp = $(lname("_m")) & $(rname("_p"))
        assign mult$(handler.id)_mm = $(lname("_m")) & $(rname("_m"))
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_11 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_pp),
                .B(mult$(handler.id)_pm),
                .Y(mult$(handler.id)_11)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_12 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_pm),
                .B(mult$(handler.id)_pp),
                .Y(mult$(handler.id)_12)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_13 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_mp),
                .B(mult$(handler.id)_mm),
                .Y(mult$(handler.id)_13)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_14 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_mm),
                .B(mult$(handler.id)_mp),
                .Y(mult$(handler.id)_14)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_11),
                .B(mult$(handler.id)_14),
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_12),
                .B(mult$(handler.id)_13),
                .Y($(name(outputs[1]))_m)
            );
        // END mult$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

function (handler::SMatMultHandler)(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
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
    push!(netlist, Net(name = "mmult$(handler.id)_pp", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_pm", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_mp", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_mm", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_11", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_12", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_13", size = outsize))
    push!(netlist, Net(name = "mmult$(handler.id)_14", size = outsize))

    outstring = """
        $stdcomment
        // BEGIN mmult$(handler.id)
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_p),
                .B($(name(inputs[2]))_p),
                .Y(mmult$(handler.id)_pp)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_pm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_p),
                .B($(name(inputs[2]))_m),
                .Y(mmult$(handler.id)_pm)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .B($(name(inputs[2]))_p),
                .Y(mmult$(handler.id)_mp)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(name(inputs[1]))_m),
                .B($(name(inputs[2]))_m),
                .Y(mmult$(handler.id)_mm)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_11 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_pp),
                .B(mmult$(handler.id)_pm),
                .Y(mmult$(handler.id)_11)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_12 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_pm),
                .B(mmult$(handler.id)_pp),
                .Y(mmult$(handler.id)_12)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_13 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_mp),
                .B(mmult$(handler.id)_mm),
                .Y(mmult$(handler.id)_13)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_14 (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_mm),
                .B(mmult$(handler.id)_mp),
                .Y(mmult$(handler.id)_14)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_11),
                .B(mmult$(handler.id)_14),
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_12),
                .B(mmult$(handler.id)_13),
                .Y($(name(outputs[1]))_m)
            );
        // END mmult$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end