struct IdentityHandler end

is_hardware_primitive(::Type{typeof(identity)}, x) = true
is_hardware_primitive(::Type{typeof(Base.broadcasted)}, ::Type{typeof(identity)}, x) = true
gethandler(::Bool, ::Type{typeof(identity)}, x) = IdentityHandler()
init_state(::IdentityHandler) = nothing

function (handler::IdentityHandler)(buffer, netlist, state, inputs, outputs)
    write(buffer, "// BEGIN identity\n")
    write(buffer, join(map(suffixes(inputs[1]), suffixes(outputs[1])) do sufxi, sufxo
        @assert (sufxi == sufxo) "IdentityHandler encountered input and output with mismatched suffixes: $sufxi and $sufxo."
        "assign $(name(outputs[1]))_$sfxo = $(name(inputs[1]))_$sfxi;"
    end, "\n"))
    write(buffer, "// END identity\n\n")

    return buffer, state
end
