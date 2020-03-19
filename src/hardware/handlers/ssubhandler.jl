@kwdef mutable struct SSubHandler <: AbstractHandler
    id = 0
end

@register(SSubHandler, -, begin
    [SBit, SBit] => [SBit]
    [SBit, Vector{SBit}] => [Vector{SBit}]
    [Vector{SBit}, SBit] => [Vector{SBit}]
    [Vector{SBit}, Vector{SBit}] => [Vector{SBit}]
    [SBit, Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{SBit}, SBit] => [Matrix{SBit}]
    [Matrix{SBit}, Matrix{SBit}] => [Matrix{SBit}]
end)

function (handler::SSubHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable})
    # update netlist with inputs
    setsigned!(netlist, getname(inputs[1]), true)
    setsigned!(netlist, getname(inputs[2]), true)

    # compute output size
    lname, rname, outsize = handlebroadcast(inputs[1].name, inputs[2].name,
                                            getsize(netlist, getname(inputs[1])),
                                            getsize(netlist, getname(inputs[2])))

    # add output net to netlist
    setsigned!(netlist, getname(outputs[1]), true)

    # add internal nets to netlist
    update!(netlist, Net(name = "sub$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "sub$(handler.id)_pm", size = outsize))
    update!(netlist, Net(name = "sub$(handler.id)_mp", size = outsize))
    update!(netlist, Net(name = "sub$(handler.id)_mm", size = outsize))

    outstring = """
        $stdcomment
        // BEGIN sub$(handler.id)
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_m"))),
                .Y(sub$(handler.id)_pp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_pm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(rname("_p"))),
                .B($(lname("_m"))),
                .Y(sub$(handler.id)_pm)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(rname("_m"))),
                .B($(lname("_m"))),
                .Y(sub$(handler.id)_mp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_m"))),
                .Y(sub$(handler.id)_mm)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(sub$(handler.id)_pp),
                .B(sub$(handler.id)_mp),
                .Y($(outputs[1].name)_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(sub$(handler.id)_pm),
                .B(sub$(handler.id)_mm),
                .Y($(outputs[1].name)_m)
            );
        // END sub$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end