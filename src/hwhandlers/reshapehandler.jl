struct ReshapeHandler end

is_hardware_primitive(::Type{typeof(reshape)}, args...) = true
gethandler(broadcasted, ::Type{typeof(reshape)}, args...) =
    !broadcasted ? ReshapeHandler() : error("Cannot generate hardware for broadcasted reshape.")
init_state(::ReshapeHandler) = nothing

function (handler::ReshapeHandler)(buffer, netlist, state, inputs, outputs)
    for input in inputs[2:end]
        delete!(netlist, input)
    end

    write(buffer, "// BEGIN reshape\n")
    write(buffer, join(map(suffixes(inputs[1]), suffixes(outputs[1])) do sufxi, sufxo
        @assert (sufxi == sufxo) "ReshapeHandler encountered input and output with mismatched suffixes: $sufxi and $sufxo."
        "assign $(name(outputs[1]))_$sfxo = $(name(inputs[1]))_$sfxi;"
    end, "\n"))
    write(buffer, "// END reshape\n\n")

    return buffer, state
end
