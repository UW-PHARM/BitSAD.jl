@kwdef mutable struct FxpAddHandler <: AbstractHandler
    id = 0
end

@register(FxpAddHandler, +, [Number, Number] => [Number])

function (handler::FxpAddHandler)(netlist::Netlist,
                                  inputs::Vector{Variable},
                                  outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("FXP add does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN f_add$(handler.id)
        fxp_add #(
                .BIT_WIDTH(BIT_WIDTH)
            ) f_add$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END f_add$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end