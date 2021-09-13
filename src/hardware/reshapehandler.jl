is_hardware_primitive(::Type{typeof(reshape)}, args...) = true
gethandler(::Type{typeof(reshape)}, args...) = reshape_handler

function reshape_handler(netlist::Netlist, inputs::Vector{Net}, outputs::Vector{Net})
    for input in inputs[2:end]
        delete!(netlist, input)
    end

    outstring = """
        $stdcomment
        // BEGIN reshape
        assign $(name(outputs[1])) = $(name(inputs[1]))
        // END reshape
        \n"""

    return outstring
end
