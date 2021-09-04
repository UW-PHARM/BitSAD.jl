function getfxpwidths(x::Real)
    xabs = abs(x)
    xint = floor(xabs)
    intwidth = Int(max(ceil(log2(xint)), 0))
    fracwidth = Int(min(ceil(-log2(xabs - xint)), 0))

    return (integral = intwidth, fractional = fracwidth)
end

function getfixedpoint(x::Real, width)
    xabs = abs(x)
    intrep = Int(floor(xabs * 2^width.fractional))
    bitwidth = width.integral + width.fractional + 1
    binstr = "$(x < 0 ? "-" : "")$bitwidth'b$(string(intrep; pad = bitwidth, base = 2))"

    return binstr
end

function constantreplacement!(m::Module)
    maxintwidth = 1
    maxfracwidth = 0

    # find require widths
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        for input in inputs
            if isconstant(input)
                width = getfxpwidths(value(input))
                maxintwidth = max(maxintwidth, width.integral)
                maxfracwidth = max(maxfracwidth, width.fractional)
            end
        end
    end

    # replace all constants
    width = (integral = maxintwidth, fractional = maxfracwidth)
    # constreplacements = []
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        for (i, input) in enumerate(inputs)
            if isconstant(input)
                conststr = getfixedpoint(value(input), width)
                inputs[i] = setname(input, conststr)
            elseif isparameter(input)
                conststr = getfixedpoint(value(input), width)
                m.parameters[name(input)] = conststr
            end
        end
        set_prop!(m.dfg, v, :inputs, inputs)
    end

    return width
end
