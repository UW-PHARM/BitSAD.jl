@kwdef mutable struct TransposeHandler <: AbstractHandler
    id = 0
end

register(Operation([Symbol("Vector{SBit}")], [Symbol("Matrix{SBit}")], :permutedims), TransposeHandler)
register(Operation([Symbol("Vector{DBit}")], [Symbol("Matrix{DBit}")], :permutedims), TransposeHandler)
register(Operation([Symbol("Matrix{SBit}")], [Symbol("Matrix{SBit}")], :permutedims), TransposeHandler)
register(Operation([Symbol("Matrix{DBit}")], [Symbol("Matrix{DBit}")], :permutedims), TransposeHandler)

function (handler::TransposeHandler)(netlist::Netlist,
                                     inputs::Vector{Variable},
                                     outputs::Vector{Variable},
                                     sizes::Vector{Tuple{Int, Int}})
    # compute output size
    outsize = (sizes[1][2], sizes[1][1])

    # add output net to netlist
    update!(netlist, Net(name = string(outputs[1].name), signed = true, size = outsize))

    outstring = """
        $stdcomment
        // BEGIN transpose$(handler.id)
        $(id > 0 ? "" : "integer i, j;")
        always @(*) begin
            for (i = 0; i < $(sizes[1][1]); i = i + 1) begin
                for (j = 0; j < $(sizes[1][2]); j = j + 1) begin
                    $(outputs[1].name)_p[(j*$(sizes[1][1])) + i] <= $(inputs[1].name)_p[(i*$(sizes[1][2])) + j];
                    $(outputs[1].name)_m[(j*$(sizes[1][1])) + i] <= $(inputs[1].name)_m[(i*$(sizes[1][2])) + j];
                end
            end
        end
        // END transpose$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end