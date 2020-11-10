_genid() = unsafe_trunc(UInt32, uuid4().value)
_indexid(id::UInt32, idx::Integer) = unsafe_trunc(UInt32, uuid5(UUID(id), "[$idx]").value)
_getidstr(x::AbstractBitstream) = digits(UInt8, x.id; base = 16, pad = 8)
_getidstr(x) = Vector{UInt8}(string(x))
_getidstr(x::VecOrMat) = mapreduce(_getidstr, vcat, x)

id(s::SBitstream) = s.id
id(x) = x

const SBitstreamLike = Union{<:SBitstream, VecOrMat{<:SBitstream}}
const SimulatableOp = @NamedTuple{op::Symbol, args::UInt32}
const SimulatableReturn = @NamedTuple{val::SBitstreamLike, op::SOperator}

struct SimulatableState
    bitmap::Dict{UInt32, SBit}
    opmap::Dict{SimulatableOp, SimulatableReturn}
end
SimulatableState() = SimulatableState(Dict(), Dict())

function getbit!(state::SimulatableState, x::SBitstream)
    if haskey(state.bitmap, x.id)
        return state.bitmap[x.id]
    else
        b = pop!(x)
        state.bitmap[x.id] = b
        
        return b
    end
end
getbit!(state::SimulatableState, x::VecOrMat{<:SBitstream}) = getbit!.(Ref(state), x)
getbit!(state::SimulatableState, x) = x

function setbit!(state::SimulatableState, x::SBitstream)
    state.bitmap[x.id] = observe(x)
end
setbit!(state::SimulatableState, x::VecOrMat{<:SBitstream}) = setbit!.(Ref(state), x)
setbit!(state::SimulatableState, x) = nothing

clearbits!(state::SimulatableState) = empty!(state.bitmap)
clearops!(state::SimulatableState) = empty!(state.opmap)

Cassette.@context SimulatableCtx

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
        error("SBit only supports divisors > 0.")
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
macro simulatable(ex)
    @capture(ex, fdef_ => optype_(opargs__)) ||
        error("Cannot parse expression $ex in @simulatable. Expected: f(arg1, arg2, ...) => Operator(oparg1, oparg2, ...)")
    @capture(fdef, f_(args__)) || error("Cannot parse expression $f in @simulatable. Expected: f(arg1, arg2, ...)")
    argsyms = map(x -> splitarg(x)[1], args)
    argtypes = map(x -> splitarg(x)[2], args)
    id_args = map(x -> :(id.(x)), argsyms)
    popped_args = map(x -> :(getbit!(ctx.metadata, $x)), argsyms)

    return quote
        function Cassette.overdub(ctx::SimulatableCtx, ::typeof($f), $(args...))
            opkey = (op = Symbol($f), args = hashn!(UInt32, _getidstr([$(id_args...)])))
            if haskey(ctx.metadata.opmap, opkey)
                out = ctx.metadata.opmap[opkey]
                push!(out.val, out.op($(popped_args...)))
                setbit!(ctx.metadata, out.val)
        
                return out.val
            else
                op = $(optype)($(opargs...))
                val = Cassette.fallback(ctx, $f, $(argsyms...))
                push!(val, op($(popped_args...)))
                setbit!(ctx.metadata, val)
                ctx.metadata.opmap[opkey] = (val = val, op = op)
        
                return val
            end
        end
    end
end

macro simulate(ex)
    if @capture(ex, for var_ in itr_ body_ end)
        return quote
            ctx = BitSAD.SimulatableCtx(metadata = BitSAD.SimulatableState())
            for $(esc(var)) in $(esc(itr))
                Cassette.@overdub ctx $(esc(body))
                clearbits!(ctx.metadata)
            end
        end
    else
        return quote
            Cassette.@overdub BitSAD.SimulatableCtx(metadata = BitSAD.SimulatableState()) $(esc(ex))
        end
    end
end