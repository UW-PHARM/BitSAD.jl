function insertrng!(m::Module)
    id = 0
    # replace all SBitstream constants
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        for (i, input) in enumerate(inputs)
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
        end
    end

    return m
end
