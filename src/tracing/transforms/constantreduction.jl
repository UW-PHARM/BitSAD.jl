_isreducible(m::CircuitModule, v) = (getoperator(m.dfg, v).type != typeof(SBitstream)) &&
                             all(isconstant, getinputs(m.dfg, v))

function _reducenode!(m::CircuitModule, v)
    # determine constant
    val = value.(getoutputs(m.dfg, v))

    # double check result
    isreal(val) || error("""
        Tried to reduce node, but received non-numeric result: $val
            args: $(value.(getinputs(m.dfg, v)))
            op: $(getoperator(m.dfg, v))
        """)

    # delete node and propagate constant
    children = outneighbors(m.dfg, v)
    outputs = getoutputs(m.dfg, v)
    for child in children
        inputs = getinputs(m.dfg, child)
        for (j, output) in enumerate(outputs)
            for (i, input) in enumerate(inputs)
                if name(input) == name(output)
                    inputs[i] = Net(val[j]; name = string(val[j]), class = :constant)
                end
            end
            set_prop!(m.dfg, child, :inputs, inputs)
        end
    end
    rem_vertex!(m.dfg, v)

    return m
end

function constantreduction!(m::CircuitModule)
    # if there are no nodes to reduce then return
    nodes = filter(v -> _isreducible(m, v), getroots(m.dfg))
    isempty(nodes) && return m

    # reduce one node then try again
    _reducenode!(m, nodes[1])
    constantreduction!(m)

    return m
end