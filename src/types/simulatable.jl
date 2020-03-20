_opmap = Dict{Tuple{UInt32, Symbol}, Tuple{SOperator, UInt32}}()

clearops() = empty!(_opmap)

"""
    @simulatable

Make any operator simulatable by providing:
- A composite (struct) type corresponding to the hardware evaluation
- An function that computes the floating-point value

# Examples

The following makes a simulatable stochastic add operation.
```julia
@simulatable(SSignedAdder, +(x::SBit, y::SBit) = x.value + y.value)
```

The following makes a simulatable stochastic divide operation.
```julia
@simulatable(SSignedDivider,
function /(x::SBit, y::SBit)
    if y.value <= 0
        error("SBit only supports divisors > 0 (y == $y).")
    end

    x.value / y.value
end)
```

Some operators require arguments to the constructor. You can optionally specify these
to `@simulatable` as a third argument.
```julia
@simulatable(SSignedMatMultiplier,
    *(x::VecOrMat{SBit}, y::VecOrMat{SBit}) = float.(x) * float.(y), (size(x, 1), size(y, 2)))
```
"""
macro simulatable(optype, fdef, args = ())
    def = splitdef(fdef)
    opsym = "$(def[:name]) -> $optype"
    idstrs = []
    opargs = []
    for arg in splitarg.(def[:args])
        push!(idstrs, :(_getidstr($(arg[1]))))
        push!(opargs, :($(arg[1])))
    end
    hashkey = :(vcat($(idstrs...)))

    newbody = quote
        key = (hashn!($hashkey, 4), Symbol($opsym))
        if haskey(_opmap, key)
            op, id = _opmap[key]
            value = $(def[:body])

            SBit(op($(opargs...)), value, id)
        else
            op = $(optype)($args...)
            id = _genid()
            value = $(def[:body])
            outbit = SBit(op($(opargs...)), value, id)
            _opmap[key] = (op, id)

            return outbit
        end
    end
    def[:body] = newbody

    return MacroTools.combinedef(def)
end