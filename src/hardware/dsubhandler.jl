@kwdef mutable struct DSubHandler <: AbstractHandler
    id = 0
end

@register(DSubHandler, -, [DBit, DBit] => [Number])

function (handler::DSubHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic subtract does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_sub$(handler.id)
        determ_sub #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) d_sub$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_sub$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

@kwdef mutable struct DSubAHandler <: AbstractHandler
    id = 0
end

@register(DSubAHandler, -, [DBit, Number] => [Number])

function (handler::DSubAHandler)(netlist::Netlist,
                                 inputs::Vector{Variable},
                                 outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic subtract does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_suba_fxp$(handler.id)
        determ_suba_fxp #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) d_suba_fxp$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_suba_fxp$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end

@kwdef mutable struct DSubBHandler <: AbstractHandler
    id = 0
end

@register(DSubBHandler, -, [Number, DBit] => [Number])

function (handler::DSubBHandler)(netlist::Netlist,
                                 inputs::Vector{Variable},
                                 outputs::Vector{Variable})
    # check size
    if getsize(netlist, getname(inputs[1])) != (1, 1) && getsize(netlist, getname(inputs[1])) != (1, 1)
        error("Deterministic subtract does not support matrix hardware generation yet.")
    end

    outstring = """
        $stdcomment
        // BEGIN d_subb_fxp$(handler.id)
        determ_subb_fxp #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) d_subb_fxp$(handler.id) (
                .a($(inputs[1].name)),
                .b($(inputs[2].name)),
                .y($(outputs[1].name))
            );
        // END d_subb_fxp$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end