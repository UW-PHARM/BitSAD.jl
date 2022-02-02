struct ReshapeHandler end

is_hardware_primitive(::Type{typeof(reshape)}, args...) = true
gethandler(broadcasted, ::Type{typeof(reshape)}, args...) =
    !broadcasted ? ReshapeHandler() : error("Cannot generate hardware for broadcasted reshape.")
init_state(::ReshapeHandler) = nothing

function (handler::ReshapeHandler)(buffer, netlist, state, inputs, outputs)
    for input in inputs[2:end]
        delete!(netlist, input)
    end

    if issigned(inputs[1])
        setsigned!(netlist, outputs[1], true)
        write(buffer, """
            $stdcomment
            // BEGIN reshape
            assign $(name(outputs[1]))_p = $(name(inputs[1]))_p;
            assign $(name(outputs[1]))_m = $(name(inputs[1]))_m;
            // END reshape
            \n""")
    else
        write(buffer, """
            $stdcomment
            // BEGIN reshape
            assign $(name(outputs[1])) = $(name(inputs[1]));
            // END reshape
            \n""")
    end

    return buffer, state
end