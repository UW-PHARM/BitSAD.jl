function getfxpwidths(x::Real)
    xabs = abs(x)
    xint = floor(xabs)
    xfrac = xabs - xint
    intwidth = iszero(xint) ? 0 : Int(ceil(log2(xint)))
    fracwidth = iszero(xfrac) ? 0 : Int(ceil(-log2(xfrac)))

    return (integral = intwidth, fractional = fracwidth)
end
function getfxpwidths(x::AbstractArray{<:Real})
    widths = getfxpwidths.(x)

    return (integral = maximum(first.(widths)), fractional = maximum(last.(widths)))
end
function getfxpwidths(x::NTuple{N, <:Real}) where N
    widths = map(getfxpwidths, x)

    return (integral = maximum(first.(widths)), fractional = maximum(last.(widths)))
end

function getfixedpoint(x::Real, width)
    xabs = abs(x)
    intrep = Int(floor(xabs * 2^width.fractional))
    bitwidth = width.integral + width.fractional + 1
    binstr = "$(x < 0 ? "-" : "")$bitwidth'b$(string(intrep; pad = bitwidth, base = 2))"

    return binstr
end
getfixedpoint(x::AbstractArray{<:Real}, width) = getfixedpoint.(x, Ref(width))
getfixedpoint(x::NTuple{<:Any, <:Real}, width) = map(x) do xi
    getfixedpoint(xi, width)
end

function constantreplacement!(m::CircuitModule)
    maxintwidth = m.bitwidth.integral
    maxfracwidth = m.bitwidth.fractional

    # find require widths
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        for input in inputs
            if (isconstant(input) || isparameter(input)) &&
               (jltypeof(input) <: Union{Real, AbstractArray{<:Real}, NTuple{<:Any, <:Real}})
                width = getfxpwidths(value(input))
                maxintwidth = max(maxintwidth, width.integral)
                maxfracwidth = max(maxfracwidth, width.fractional)
            end
        end
    end

    # replace all constants
    m.bitwidth = (integral = maxintwidth, fractional = maxfracwidth)
    # constreplacements = []
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        for (i, input) in enumerate(inputs)
            if jltypeof(input) <: Union{Real, AbstractArray{<:Real}, NTuple{<:Any, <:Real}}
                if isconstant(input)
                    conststr = getfixedpoint(value(input), m.bitwidth)
                    inputs[i] = setwidth(setname(input, conststr), sum(m.bitwidth) + 1)
                elseif isparameter(input)
                    conststr = getfixedpoint(value(input), m.bitwidth)
                    inputs[i] = setwidth(input, sum(m.bitwidth) + 1)
                    m.parameters[name(input)] = conststr
                end
            end
        end
        set_prop!(m.dfg, v, :inputs, inputs)
    end

    return m
end
