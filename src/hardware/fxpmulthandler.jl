@kwdef mutable struct FxpMultHandler <: AbstractHandler
    id = 0
end

@register(FxpMultHandler, *, [Number, Number] => [Number])

function (handler::FxpMultHandler)(netlist::Netlist,
                                   inputs::Vector{Variable},
                                   outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("FXP multiply does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN f_mult$(handler.id)
        fxp_mult #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) f_mult$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END f_mult$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end