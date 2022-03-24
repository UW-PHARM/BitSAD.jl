function insertrng!(m::CircuitModule)
    id = 0
    # replace all SBitstream constants and re-route parameters
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        for (i, input) in enumerate(inputs)
            # replace constant
            if isconstant(input) && (jltypeof(input) <: SBitstream)
                val = Net(float(value(input));
                          name = string(float(value(input))),
                          class = :constant)
                op = (name = Symbol(""), type = typeof(SBitstream), broadcasted = false)
                input = setclass(input, :internal)
                input = setname(input, "net_rng_$id")
                id += 1
                inputs[i] = input
                set_prop!(m.dfg, v, :inputs, inputs)
                addnode!(m, [val], [input], op)
            elseif isconstant(input) && (jltypeof(input) <: AbstractArray{<:SBitstream})
                val = Net(float.(value(input));
                          name = string.(float.(value(input))),
                          class = :constant)
                op = (name = Symbol(""), type = typeof(SBitstream), broadcasted = true)
                input = setclass(input, :internal)
                input = setname(input, "net_rng_$id")
                id += 1
                inputs[i] = input
                set_prop!(m.dfg, v, :inputs, inputs)
                addnode!(m, [val], [input], op)
            end

            # re-route parameter
            # the name is fixed in the second loop below
            if isparameter(input) &&
               (jltypeof(input) <: Union{SBitstream, AbstractArray{<:SBitstream}})
                newnet = Net(value(input);
                             name = "$(name(input))_rng", class = :internal)
                inputs[i] = newnet
                set_prop!(m.dfg, v, :inputs, inputs)
            end
        end
    end

    # replace all SBitstream parameters
    for (name, value) in m.parameters
        if typeof(value) <: SBitstream
            rngin = Net(float(value); name = name, class = :parameter)
            rngout = Net(value; name = "$(name)_rng", class = :internal)
            op = (name = Symbol(""), type = typeof(SBitstream), broadcasted = false)
            m.parameters[name] = float(value)
            addnode!(m, [rngin], [rngout], op)
        elseif typeof(value) <: AbstractArray{<:SBitstream}
            rngin = Net(float.(value); name = name, class = :parameter)
            rngout = Net(value; name = "$(name)_rng", class = :internal)
            op = (name = Symbol(""), type = typeof(SBitstream), broadcasted = true)
            m.parameters[name] = float.(value)
            addnode!(m, [rngin], [rngout], op)
        end
    end

    return m
end
