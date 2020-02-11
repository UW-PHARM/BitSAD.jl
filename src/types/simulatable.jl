_opmap = Dict{Tuple{UInt32, Symbol}, Tuple{SOperator, UInt32}}()

clearops() = empty!(_opmap)

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