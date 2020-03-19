@kwdef mutable struct SAddHandler <: AbstractHandler
    id = 0
end

@register(SAddHandler, +, begin
    [SBit, SBit] => [SBit]
    [SBit, Vector{SBit}] => [Vector{SBit}]
    [Vector{SBit}, SBit] => [Vector{SBit}]
    [Vector{SBit}, Vector{SBit}] => [Vector{SBit}]
    [SBit, Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{SBit}, SBit] => [Matrix{SBit}]
    [Matrix{SBit}, Matrix{SBit}] => [Matrix{SBit}]
end)

function (handler::SAddHandler)(netlist::Netlist,
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

    outstring = """
        $stdcomment
        // BEGIN add$(handler.id)
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_p"))),
                .Y($(outputs[1].name)_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_m"))),
                .Y($(outputs[1].name)_m)
            );
        // END add$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end