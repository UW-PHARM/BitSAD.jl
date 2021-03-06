@kwdef mutable struct SDivHandler <: AbstractHandler
    id = 0
end

@register(SDivHandler, /, begin
    [SBit, SBit] => [SBit]
    [SBit, Vector{SBit}] => [Vector{SBit}]
    [Vector{SBit}, SBit] => [Vector{SBit}]
    [Vector{SBit}, Vector{SBit}] => [Vector{SBit}]
    [SBit, Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{SBit}, SBit] => [Matrix{SBit}]
    [Matrix{SBit}, Matrix{SBit}] => [Matrix{SBit}]
end)

function (handler::SDivHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable})
    # update netlist with inputs
    setsigned!(netlist, getname(inputs[1]), true)
    setsigned!(netlist, getname(inputs[2]), true)

    # compute output size
    lname, rname, outsize = handlebroadcast(inputs[1].name, inputs[2].name,
                                            getsize(netlist, getname(inputs[1])),
                                            getsize(netlist, getname(inputs[2])))

    # update netlist with output
    setsigned!(netlist, getname(outputs[1]), true)

    # add internal nets to netlist
    update!(netlist, Net(name = "div$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "div$(handler.id)_mp", size = outsize))

    outstring = """
        $stdcomment
        // BEGIN div$(handler.id)
        stoch_div_mat #(
                .COUNTER_SIZE(8),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_p"))),
                .Y(div$(handler.id)_pp)
            );
        stoch_div_mat #(
                .COUNTER_SIZE(8),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_p"))),
                .Y(div$(handler.id)_mp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(div$(handler.id)_pp),
                .B(div$(handler.id)_mp),
                .Y($(outputs[1].name)_p)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(div$(handler.id)_mp),
                .B(div$(handler.id)_pp),
                .Y($(outputs[1].name)_m)
            );
        // END div$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end