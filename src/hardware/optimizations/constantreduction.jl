function isreducible(m::Module, v)
    inputs = map(x -> x.name, getinputs(m.dfg, v))

    return all(x -> haskey(m.parameters, x), inputs)
end

function reducenode!(m::Module, netlist::Netlist, v)
    # determine constant
    args = map(x -> m.parameters[x.name], getinputs(m.dfg, v))
    op = getoperator(m.dfg, v)
    value = eval(:($op($(args...))))

    # double check result
    isreal(value) || error("""
        Tried to reduce node, but received non-numeric result: $value
            args: $args
            op: $op
        """)

    # delete node and propagate constant
    children = outneighbors(m.dfg, v)
    outputs = getoutputs(m.dfg, v)
    for child in children
        for output in outputs
            inputs = getinputs(m.dfg, child)
            for (i, input) in enumerate(inputs)
                if getname(input) ∈ getname.(outputs)
                    inputs[i] = Variable(Symbol(value), Symbol(typeof(value)))
                end
            end
            set_prop!(m.dfg, child, :inputs, inputs)
        end
    end
    rem_vertex!(m.dfg, v)

    # add constant to netlist
    update!(netlist, Net(name = string(value), class = :constant, size = (1, 1)))

    return m
end

function constantreduction!(m::Module, netlist::Netlist)
    # if there are no nodes to reduce then return
    nodes = filter(v -> isreducible(m, v), getroots(m.dfg))
    isempty(nodes) && return m

    # reduce one node then try again
    reducenode!(m, netlist, nodes[1])
    constantreduction!(m, netlist)

    return m
end