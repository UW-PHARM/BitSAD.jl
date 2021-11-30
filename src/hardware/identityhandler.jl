is_hardware_primitive(::Type{typeof(identity)}, x) = true
gethandler(::Bool, ::Type{typeof(identity)}, x) = identity_handler

function identity_handler(buffer, netlist, inputs, outputs)
    if issigned(inputs[1])
        setsigned!(netlist, outputs[1], true)
        write(buffer, """
            $stdcomment
            // BEGIN identity
            assign $(name(outputs[1]))_p = $(name(inputs[1]))_p;
            assign $(name(outputs[1]))_m = $(name(inputs[1]))_m;
            // END identity
            \n""")
    else
        write(buffer, """
            $stdcomment
            // BEGIN identity
            assign $(name(outputs[1])) = $(name(inputs[1]));
            // END identity
            \n""")
    end

    return buffer
end
