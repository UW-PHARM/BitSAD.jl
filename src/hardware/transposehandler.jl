@kwdef mutable struct TransposeHandler
    id::Int = 0
end

gethandler(broadcasted, ::Type{typeof(permutedims)}, ::Type{<:SBitstreamLike}) =
    !broadcasted ? TransposeHandler() :
                   error("Cannot generate hardware for broadcasted transpose (permutedims).")

function (handler::TransposeHandler)(buffer, netlist, inputs, outputs)
    # compute output size
    outsize = netsize(outputs[1])

    # add output net to netlist
    setsigned!(netlist, outputs[1], true)
    setreg!(netlist, outputs[1])

    write(buffer, """
        $stdcomment
        // BEGIN transpose$(handler.id)
        $(handler.id > 0 ? "" : "integer i, j;")
        always @(*) begin
            for (i = 0; i < $(outsize[2]); i = i + 1) begin
                for (j = 0; j < $(outsize[1]); j = j + 1) begin
                    $(name(outputs[1]))_p[(j*$(outsize[2])) + i] <= $(name(inputs[1]))_p[(i*$(outsize[1])) + j];
                    $(name(outputs[1]))_m[(j*$(outsize[2])) + i] <= $(name(inputs[1]))_m[(i*$(outsize[1])) + j];
                end
            end
        end
        // END transpose$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end