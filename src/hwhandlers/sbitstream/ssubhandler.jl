struct SSubHandler end

gethandler(broadcasted, ::Type{typeof(-)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) = SSubHandler()
init_state(::SSubHandler) = (id = 0,)

function (handler::SSubHandler)(buffer, netlist, state, inputs, outputs)
    # compute output size
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # add internal nets to netlist
    push!(netlist, Net(name = "sub$(state.id)_out_pp", size = outsize))
    push!(netlist, Net(name = "sub$(state.id)_out_pm", size = outsize))
    push!(netlist, Net(name = "sub$(state.id)_out_mp", size = outsize))
    push!(netlist, Net(name = "sub$(state.id)_out_mm", size = outsize))

    write(buffer, """
        // BEGIN sub$(state.id)
        stoch_signed_sub_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(state.id) (
                .CLK(CLK),
                .nRST(nRST),
                .A_p($(lname("_p"))),
                .A_m($(lname("_m"))),
                .B_p($(rname("_p"))),
                .B_m($(rname("_m"))),
                .Y_p($(name(outputs[1]))_p),
                .Y_m($(name(outputs[1]))_m)
            );
        // END sub$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
