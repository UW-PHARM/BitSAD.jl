@kwdef mutable struct DMultHandler <: AbstractHandler
    id = 0
end

@register(DMultHandler, *, [DBit, DBit] => [Number])

function (handler::DMultHandler)(netlist::Netlist,
                                 inputs::Vector{Variable},
                                 outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic multiply does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_mult$(handler.id)
        determ_mult d_mult$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_mult$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

@kwdef mutable struct DMultFxpHandler <: AbstractHandler
    id = 0
end

@register(DMultFxpHandler, *, begin
    [DBit, Number] => [Number]
    [Number, DBit] => [Number]
end)

function (handler::DMultFxpHandler)(netlist::Netlist,
                                    inputs::Vector{Variable},
                                    outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic multiply does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_mult_fxp$(handler.id)
        determ_mult_fxp #(
                .BIT_WIDTH(BIT_WIDTH)
            ) d_mult_fxp$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_mult_fxp$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end