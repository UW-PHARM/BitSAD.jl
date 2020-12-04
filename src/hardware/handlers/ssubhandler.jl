@kwdef mutable struct SSubHandler <: AbstractHandler
    id = 0
end

istraceprimitive(::typeof(-), ::SBitstreamLike, ::SBitstreamLike) = true
gethandler(::Type{typeof(-)}, ::Type{<:SBitstreamLike}, ::Type{<:SBitstreamLike}) = SSubHandler()

function (handler::SSubHandler)(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
    # update netlist with inputs
    setsigned!(netlist, inputs[1], true)
    setsigned!(netlist, inputs[2], true)

    # compute output size
    lname, rname = handlebroadcast(name(inputs[1]), name(inputs[2]),
                                   netsize(inputs[1]), netsize(inputs[2]))
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    # add internal nets to netlist
    push!(netlist, Net(name = "sub$(handler.id)_pp", size = outsize))
    push!(netlist, Net(name = "sub$(handler.id)_pm", size = outsize))
    push!(netlist, Net(name = "sub$(handler.id)_mp", size = outsize))
    push!(netlist, Net(name = "sub$(handler.id)_mm", size = outsize))

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
                .Y($(name(outputs[1]))_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) sub$(handler.id)_m (
                .CLK(CLK),
                .nRST(nRST),
                .A(sub$(handler.id)_pm),
                .B(sub$(handler.id)_mm),
                .Y($(name(outputs[1]))_m)
            );
        // END sub$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end