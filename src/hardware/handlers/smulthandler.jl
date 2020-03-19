@kwdef mutable struct SMultHandler <: AbstractHandler
    id = 0
end

@kwdef mutable struct SMatMultHandler <: AbstractHandler
    id = 0
end

@register(SMultHandler, *, begin
    [SBit, SBit] => [SBit]
    [SBit, Vector{SBit}] => [Vector{SBit}]
    [Vector{SBit}, SBit] => [Vector{SBit}]
    [SBit, Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{SBit}, SBit] => [Matrix{SBit}]
end)
@register(SMatMultHandler, *, begin
    [Vector{SBit}, Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{SBit}, Vector{SBit}] => [Vector{SBit}]
    [Matrix{SBit}, Matrix{SBit}] => [Matrix{SBit}]
end)

function (handler::SMultHandler)(netlist::Netlist,
                                 inputs::Vector{Variable},
                                 outputs::Vector{Variable})
    # update netlist with inputs
    setsigned!(netlist, getname(inputs[1]), true)
    setsigned!(netlist, getname(inputs[2]), true)

    # compute output size
    lname, rname, outsize = handlebroadcast(inputs[1].name, inputs[2].name,
                                            getsize(netlist, getname(inputs[1])),
                                            getsize(netlist, getname(inputs[2])))

    # add internal nets to netlist
    update!(netlist, Net(name = "mult$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_pm", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_mp", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_mm", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_11", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_12", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_13", size = outsize))
    update!(netlist, Net(name = "mult$(handler.id)_14", size = outsize))

    # add output net to netlist
    setsigned!(netlist, getname(outputs[1]), true)

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
                .Y($(outputs[1].name)_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mult$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(mult$(handler.id)_12),
                .B(mult$(handler.id)_13),
                .Y($(outputs[1].name)_m)
            );
        // END mult$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

function (handler::SMatMultHandler)(netlist::Netlist,
                                    inputs::Vector{Variable},
                                    outputs::Vector{Variable})
    # update netlist with inputs
    setsigned!(netlist, getname(inputs[1]), true)
    setsigned!(netlist, getname(inputs[2]), true)

    # compute output size
    m, n = getsize(netlist, getname(inputs[1]))
    _, p = getsize(netlist, getname(inputs[2]))
    outsize = getsize(netlist, getname(outputs[1]))

    # add output net to netlist
    setsigned!(netlist, getname(outputs[1]), true)

    # add internal nets to netlist
    update!(netlist, Net(name = "mmult$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_pm", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_mp", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_mm", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_11", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_12", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_13", size = outsize))
    update!(netlist, Net(name = "mmult$(handler.id)_14", size = outsize))

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
                .A($(inputs[1].name)_p),
                .B($(inputs[2].name)_p),
                .Y(mmult$(handler.id)_pp)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_pm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_p),
                .B($(inputs[2].name)_m),
                .Y(mmult$(handler.id)_pm)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_m),
                .B($(inputs[2].name)_p),
                .Y(mmult$(handler.id)_mp)
            );
        stoch_matrix_mult #(
                .NUM_ROWS($m),
                .NUM_MID($n),
                .NUM_COLS($p)
            ) mmult$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_m),
                .B($(inputs[2].name)_m),
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
                .Y($(outputs[1].name)_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) mmult$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(mmult$(handler.id)_12),
                .B(mmult$(handler.id)_13),
                .Y($(outputs[1].name)_m)
            );
        // END mmult$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end