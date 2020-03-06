@kwdef mutable struct SAddHandler <: AbstractHandler
    id = 0
end

register(Operation([:SBit, :SBit], [:SBit], :+), SAddHandler)
register(Operation([Symbol("Vector{SBit}"), Symbol("Vector{SBit}")], [Symbol("Vector{SBit}")], :+), SAddHandler)
register(Operation([Symbol("Matrix{SBit}"), Symbol("Matrix{SBit}")], [Symbol("Matrix{SBit}")], :+), SAddHandler)

function (handler::SAddHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable},
                                sizes::Vector{Tuple{Int, Int}})
    # compute output size
    outsize = sizes[1]

    # add internal nets to netlist
    update!(netlist, Net(name = "add$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "add$(handler.id)_mm", size = outsize))

    # add output net to netlist
    update!(netlist, Net(name = string(outputs[1].name), signed = true, size = outsize))

    outstring = """
        $stdcomment
        // BEGIN add$(handler.id)
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_p),
                .B($(inputs[2].name)_p),
                .Y(add$(handler.id)_pp)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_m),
                .B($(inputs[2].name)_m),
                .Y(add$(handler.id)_mm)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(add$(handler.id)_pp),
                .B(add$(handler.id)_mm),
                .Y($(outputs[1].name)_p)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(add$(handler.id)_mm),
                .B(add$(handler.id)_pp),
                .Y($(outputs[1].name)_m)
            );
        // END add$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end