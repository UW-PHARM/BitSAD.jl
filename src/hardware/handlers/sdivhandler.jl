@kwdef mutable struct SDivHandler <: AbstractHandler
    id = 0
end

register(Operation([:SBit, :SBit], [:SBit], :/), SDivHandler)
register(Operation([Symbol("Vector{SBit}"), Symbol("Vector{SBit}")], [Symbol("Vector{SBit}")], :/), SDivHandler)
register(Operation([Symbol("Matrix{SBit}"), Symbol("Matrix{SBit}")], [Symbol("Matrix{SBit}")], :/), SDivHandler)

function (handler::SDivHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable},
                                sizes::Vector{Tuple{Int, Int}})
    # compute output size
    outsize = sizes[1]

    # add internal nets to netlist
    update!(netlist, Net(name = "div$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "div$(handler.id)_mp", size = outsize))

    # add output net to netlist
    update!(netlist, Net(name = string(outputs[1].name), signed = true, size = outsize))

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
                .A($(inputs[1])_p),
                .B($(inputs[2])_p),
                .Y(div$(handler.id)_pp)
            );
        stoch_div_mat #(
                .COUNTER_SIZE(8),
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1])_m),
                .B($(inputs[2])_p),
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