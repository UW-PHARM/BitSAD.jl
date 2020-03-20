@kwdef mutable struct SDMHandler <: AbstractHandler
    id = 0
end

@register(SDMHandler, SDM, [Number] => [DBit])

function (handler::SDMHandler)(netlist::Netlist,
                               inputs::Vector{Variable},
                               outputs::Vector{Variable})
    outstring = """
        $stdcomment
        // BEGIN sdm$(handler.id)
        sdm #(
                .BIT_WIDTH(BIT_WIDTH),
                .INT_WIDTH(INT_WIDTH)
            ) sdm$(handler.id) (
                .CLK(CLK),
                .nRST(nRST),
                .x($(inputs[1].name)),
                .y($(outputs[1].name))
            );
        // END sdm$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end