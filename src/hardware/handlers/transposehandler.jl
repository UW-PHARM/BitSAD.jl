@kwdef mutable struct TransposeHandler <: AbstractHandler
    id = 0
end

@register(TransposeHandler, permutedims, begin
    [Vector{SBit}] => [Matrix{SBit}]
    [Vector{DBit}] => [Matrix{DBit}]
    [Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{DBit}] => [Matrix{DBit}]
end)

function (handler::TransposeHandler)(netlist::Netlist,
                                     inputs::Vector{Variable},
                                     outputs::Vector{Variable})
    # compute output size
    outsize = getsize(netlist, getname(outputs[1]))

    # add output net to netlist
    setsigned!(netlist, getname(outputs[1]), true)
    setreg!(netlist, getname(outputs[1]))

    outstring = """
        $stdcomment
        // BEGIN transpose$(handler.id)
        $(handler.id > 0 ? "" : "integer i, j;")
        always @(*) begin
            for (i = 0; i < $(outsize[2]); i = i + 1) begin
                for (j = 0; j < $(outsize[1]); j = j + 1) begin
                    $(outputs[1].name)_p[(j*$(outsize[2])) + i] <= $(inputs[1].name)_p[(i*$(outsize[1])) + j];
                    $(outputs[1].name)_m[(j*$(outsize[2])) + i] <= $(inputs[1].name)_m[(i*$(outsize[1])) + j];
                end
            end
        end
        // END transpose$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end