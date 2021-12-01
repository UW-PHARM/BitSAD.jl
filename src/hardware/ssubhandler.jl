@kwdef mutable struct SSubHandler
    id::Int = 0
    broadcasted::Bool
end

gethandler(broadcasted, ::Type{typeof(-)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) =
    SSubHandler(broadcasted = broadcasted)

function (handler::SSubHandler)(buffer, netlist, inputs, outputs)
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output size
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    broadcast = handler.broadcasted ? "_bcast" : ""

    # add internal nets to netlist
    push!(netlist, Net(name = "sub$(broadcast)$(handler.id)_out_pp", size = outsize))
    push!(netlist, Net(name = "sub$(broadcast)$(handler.id)_out_pm", size = outsize))
    push!(netlist, Net(name = "sub$(broadcast)$(handler.id)_out_mp", size = outsize))
    push!(netlist, Net(name = "sub$(broadcast)$(handler.id)_out_mm", size = outsize))

    write(buffer, """
        $stdcomment
        // BEGIN sub$(broadcast)$(handler.id)
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(broadcast)$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_m"))),
                .Y(sub$(broadcast)$(handler.id)_out_pp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(broadcast)$(handler.id)_pm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(rname("_p"))),
                .B($(lname("_m"))),
                .Y(sub$(broadcast)$(handler.id)_out_pm)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(broadcast)$(handler.id)_mp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(rname("_m"))),
                .B($(lname("_m"))),
                .Y(sub$(broadcast)$(handler.id)_out_mp)
            );
        stoch_sat_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(broadcast)$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_m"))),
                .Y(sub$(broadcast)$(handler.id)_out_mm)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(broadcast)$(handler.id)_p (
                .CLK(CLK),
                .nRST(nRST),
                .A(sub$(broadcast)$(handler.id)_out_pp),
                .B(sub$(broadcast)$(handler.id)_out_mp),
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(broadcast)$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(sub$(broadcast)$(handler.id)_out_pm),
                .B(sub$(broadcast)$(handler.id)_out_mm),
                .Y($(name(outputs[1]))_m)
            );
        // END sub$(broadcast)$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end