_opmap = Dict{Tuple{UInt128, Symbol}, Tuple{SOperator, UUID}}()

macro simulatable(optype, fdef, args = ())
    def = splitdef(fdef)
    opsym = "$(def[:name]) -> $optype"
    idstr = ""
    opargs = []
    for arg in splitarg.(def[:args])
        idstr = "$idstr\$($(arg[1]))"
        push!(opargs, :($(arg[1])))
    end

    newbody = quote
        key = (hashn($idstr, 16), Symbol($opsym))
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