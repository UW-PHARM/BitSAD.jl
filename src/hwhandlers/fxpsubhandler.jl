@kwdef mutable struct FxpSubHandler <: AbstractHandler
    id = 0
end

@register(FxpSubHandler, -, [Number, Number] => [Number])

function (handler::FxpSubHandler)(netlist::Netlist,
                                  inputs::Vector{Variable},
                                  outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("FXP subtract does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN f_sub$(handler.id)
        fxp_sub #(
                .BIT_WIDTH(BIT_WIDTH)
            ) f_sub$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END f_sub$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end