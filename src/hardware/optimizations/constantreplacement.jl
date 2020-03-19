function getfxpwidths(x::Real)
    xabs = abs(x)
    intwidth = Int(max(ceil(log2(floor(x))), 0))
    fracwidth = Int(max(ceil(-log2(xabs - floor(x))), 0))

    return (I = intwidth, F = fracwidth)
end

function getfixedpoint(x::Real, width)
    xabs = abs(x)
    intrep = Int(floor(xabs * 2^width[:F]))
    bitwidth = width[:I] + width[:F] + 1
    binstr = "$(x < 0 ? "-" : "")$bitwidth'b$(string(intrep; pad = bitwidth, base = 2))"

    return binstr
end

function constantreplacement!(m::Module, netlist::Netlist)
    maxintwidth = 1
    maxfracwidth = 0

    # find require widths
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        outputs = getoutputs(m.dfg, v)
        op = Operation(gettype.(inputs), gettype.(outputs), getoperator(m.dfg, v))
        if allowconstreplace(gethandler(op))
            for input in inputs
                i = find(netlist, getname(input))
                if !isnothing(i) && isconstant(netlist[i])
                    width = getfxpwidths(parse(Float64, netlist[i].name))
                    maxintwidth = max(maxintwidth, width[:I])
                    maxfracwidth = max(maxfracwidth, width[:F])
                end
            end
        end
    end

    # replace all constants
    width = (I = maxintwidth, F = maxfracwidth)
    constreplacements = []
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        outputs = getoutputs(m.dfg, v)
        op = Operation(gettype.(inputs), gettype.(outputs), getoperator(m.dfg, v))
        if allowconstreplace(gethandler(op))
            for (j, input) in enumerate(inputs)
                i = find(netlist, getname(input))
                if !isnothing(i) && isconstant(netlist[i])
                    conststr = getfixedpoint(parse(Float64, netlist[i].name), width)
                    push!(constreplacements, netlist[i].name => conststr)
                    inputs[j] = Variable(Symbol(conststr), input.type)
                end
            end
            set_prop!(m.dfg, v, :inputs, inputs)
        end
    end

    # update netlist
    for (orig, new) in unique(constreplacements)
        i = find(netlist, orig)
        update!(netlist, Net(name = new, class = :constant, size = (1, 1)))
    end

    return m
end