@kwdef mutable struct SSubHandler <: AbstractHandler
    id = 0
end

register(Operation([:SBit, :SBit], [:SBit], :-), SSubHandler)
register(Operation([Symbol("Vector{SBit}"), Symbol("Vector{SBit}")], [Symbol("Vector{SBit}")], :-), SSubHandler)
register(Operation([Symbol("Matrix{SBit}"), Symbol("Matrix{SBit}")], [Symbol("Matrix{SBit}")], :-), SSubHandler)

function (handler::SSubHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable},
                                sizes::Vector{Tuple{Int, Int}})
    # compute output size
    outsize = sizes[1]

    # add internal nets to netlist
    update!(netlist, Net(name = "sub$(handler.id)_pp", size = outsize))
    update!(netlist, Net(name = "sub$(handler.id)_pm", size = outsize))
    update!(netlist, Net(name = "sub$(handler.id)_mp", size = outsize))
    update!(netlist, Net(name = "sub$(handler.id)_mm", size = outsize))

    # add output net to netlist
    update!(netlist, Net(name = string(outputs[1].name), signed = true, size = outsize))

    outstring = """
        $stdcomment
        // BEGIN sub$(handler.id)
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_p),
                .B($(inputs[2].name)_m),
                .Y(sub$(handler.id)_pp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_pm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[2].name)_p),
                .B($(inputs[1].name)_m),
                .Y(sub$(handler.id)_pm)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[2].name)_m),
                .B($(inputs[1].name)_m),
                .Y(sub$(handler.id)_mp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(inputs[1].name)_m),
                .B($(inputs[2].name)_m),
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