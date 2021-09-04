@kwdef mutable struct SDivHandler
    id = 0
end

gethandler(::Bool, ::Type{typeof(/)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) =
    SDivHandler()

function (handler::SDivHandler)(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output size
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # update netlist with output
    setsigned!(netlist, outputs[1], true)

    # add internal nets to netlist
    push!(netlist, Net(name = "div$(handler.id)_pp", size = outsize))
    push!(netlist, Net(name = "div$(handler.id)_mp", size = outsize))

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
                .Y($(name(outputs[1]))_p)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) div$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(div$(handler.id)_mp),
                .B(div$(handler.id)_pp),
                .Y($(name(outputs[1]))_m)
            );
        // END div$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end
