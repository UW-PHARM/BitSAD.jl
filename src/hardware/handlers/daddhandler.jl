@kwdef mutable struct DAddHandler <: AbstractHandler
    id = 0
end

@register(DAddHandler, +, [DBit, DBit] => [Number])

function (handler::DAddHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic add does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_add$(handler.id)
        determ_add #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) d_add$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_add$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

@kwdef mutable struct DAddFxpHandler <: AbstractHandler
    id = 0
end

@register(DAddFxpHandler, +, begin
    [DBit, Number] => [Number]
    [Number, DBit] => [Number]
end)

function (handler::DAddFxpHandler)(netlist::Netlist,
                                   inputs::Vector{Variable},
                                   outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic add does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_add_fxp$(handler.id)
        determ_add_fxp #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) d_add_fxp$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_add_fxp$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end