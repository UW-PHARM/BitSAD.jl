@kwdef mutable struct SSqrtHandler
    id::Int = 0
end

gethandler(broadcasted, ::Type{typeof(sqrt)}, ::Type{<:SBitstreamLike}) =
    !broadcasted ? SSqrtHandler() : error("Cannot generate hardware for broadcasted sqrt.")

function (handler::SSqrtHandler)(buffer, netlist, inputs, outputs)
    # add output net to netlist
    setsigned!(netlist, outputs[1], true)

    write(buffer, """
        $stdcomment
        // BEGIN sqrt$(handler.id)
        stoch_square_root #(
                .COUNTER_SIZE(10)
            ) sqrt$(handler.id) (
                .CLK  (CLK),
                .nRST (nRST),
                .up   ($(name(inputs[1]))_p),
                .un   ($(name(inputs[2]))_m),
                .y    ($(name(outputs[1]))_p)
            );
        assign $(name(outputs[1]))_m = 1'b0;
        // END sqrt$(handler.id)
        \n""")

    handler.id += 1

    return buffer
end