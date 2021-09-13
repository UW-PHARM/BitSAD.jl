_typeof(f) = typeof(f)
_typeof(T::Type) = T

is_trace_primitive(x...) = false

## Default primitives

is_trace_primitive(::Type{typeof(LinearAlgebra.norm)},
                   ::Type{<:AbstractVector},
                   ::Type{<:Any}) = true

function trace(f, args...; isprimitive = is_trace_primitive, submodules = [], ctx = Dict{Any, Any}())
    primitive_sigs =
        Ghost.FunctionResolver{Bool}([Tuple{_typeof(f), Vararg} => true for f in submodules])
    is_primitive_or_submodule(sig) =
        Ghost.is_primitive(sig) ||
        isprimitive(Ghost.get_type_parameters(sig)...) ||
        sig ∈ primitive_sigs
    _, tape = Ghost.trace(f, args...; is_primitive = is_primitive_or_submodule, ctx = ctx)

    return tape
end

function transform!(f, fctx, tape::Ghost.Tape)
    local entry, rebind_to
    itr = iterate(tape)

    while !isnothing(itr)
        entry, idx = itr

        if entry isa Ghost.Call
            new_entries, rebind_to = f(tape.c, entry)
            if isempty(new_entries)
                deleteat!(tape, idx - 1; rebind_to = rebind_to)
            else
                replace!(tape, idx - 1 => new_entries; rebind_to = rebind_to)
                vars = [tape[Ghost.Variable(idx - 1 + i)] for i in 0:(length(new_entries) - 1)]
                fctx(tape.c, vars)
            end
            idx += length(new_entries) - 1
        elseif entry isa Ghost.Input
            new_entries, rebind_to = f(tape.c, entry)
            isempty(new_entries) && error("Cannot delete Ghost.Input")
            new_vars = insert!(tape, idx, new_entries[2:end]...)
            vars = Ghost.AbstractOp[entry]
            append!(vars, [tape[v] for v in new_vars]) 
            fctx(tape.c, vars)
            idx += length(new_entries) - 1
        end

        itr = iterate(tape, idx)
        # @show tape
    end

    return tape
end
transform!(f, tape::Ghost.Tape) = transform!(f, (x...) -> nothing, tape)

squashable(x) = false
for op in (:+, :-, :*, :/, :÷)
    @eval squashable(::typeof($op)) = true
end

_squash_binary_vararg(ctx, entry) = [entry], 1
function _squash_binary_vararg(ctx, call::Ghost.Call)
    squashable(call.fn) || return [call], 1

    new_calls = accumulate(call.args[2:end]; init = call.args[1]) do x, y
        xvar = (x isa Ghost.Call) ? Ghost.Variable(x) : x
        yvar = (y isa Ghost.Call) ? Ghost.Variable(y) : y

        return Ghost.mkcall(call.fn, xvar, yvar)
    end

    return new_calls, length(new_calls)
end

_unbroadcast(ctx, entry) = [entry], 1
_unbroadcast(ctx, call::Ghost.Call{typeof(Base.broadcasted)}) =
    ([call, Ghost.mkcall(Base.materialize, Ghost.Variable(call))], 2)

struct TupleCtx
    tuple_map::Dict{Ghost.Variable, Vector{Any}}
    indexed_itr_map::Dict{Ghost.Variable, Tuple{Ghost.Variable, Int64}}
    splat_map::Dict{Ghost.Variable, Tuple{Bool, Vector{Any}}}
end
TupleCtx() = TupleCtx(Dict(), Dict(), Dict())

function Ghost.rebind_context!(tape::Ghost.Tape{TupleCtx}, subs::Dict)
    replace!(tape.c.tuple_map) do kv
        old_key, old_val = kv
        new_key = get(subs, old_key, old_key)
        new_val = [get(subs, v, v) for v in old_val]

        return new_key => new_val
    end
    replace!(tape.c.indexed_itr_map) do kv
        old_key, (old_val, i) = kv
        new_key = get(subs, old_key, old_key)
        new_val = get(subs, old_val, old_val)

        return new_key => (new_val, i)
    end
    replace!(tape.c.splat_map) do kv
        old_key, (expanded, old_val) = kv
        new_key = get(subs, old_key, old_key)
        new_val = [get(subs, v, v) for v in old_val]

        return new_key => (expanded, new_val)
    end
end

_record_tuples_and_splats(::TupleCtx, entry) = [entry], 1
function _record_tuples_and_splats(ctx::TupleCtx, call::Ghost.Call)
    if call.fn == tuple
        ctx.tuple_map[Ghost.Variable(call)] = call.args
    elseif call.fn == ntuple
        ctx.tuple_map[Ghost.Variable(call)] = [_gettapeval(call)...]
    elseif call.fn == Base.indexed_iterate && haskey(ctx.tuple_map, call.args[1])
        ctx.indexed_itr_map[Ghost.Variable(call)] = (call.args[1], _gettapeval(call.args[2]))
    elseif call.fn == Core._apply_iterate
        for arg in call.args[3:end]
            if (_gettapeop(arg).fn == tuple) || (_gettapeop(arg).fn == ntuple)
                ctx.splat_map[arg] = (true, ctx.tuple_map[arg])
            else
                ctx.splat_map[arg] = (false, [_gettapeval(arg)...])
            end
        end
    end

    return [call], 1
end

_reroute_tuple_index(::TupleCtx, entry) = [entry], 1
function _reroute_tuple_index(ctx::TupleCtx, call::Ghost.Call)
    if call.fn == Base.getfield && haskey(ctx.indexed_itr_map, call.args[1])
        if _gettapeval(call.args[2]) == 1
            indexed_itr = ctx.indexed_itr_map[call.args[1]]
            tuple_args = ctx.tuple_map[indexed_itr[1]]

            return [], tuple_args[indexed_itr[2]].id
        else
            return [], nothing
        end
    elseif call.fn == Base.getindex && haskey(ctx.tuple_map, call.args[1])
        tuple_args = ctx.tuple_map[call.args[1]]

        return [], tuple_args[_gettapeval(call.args[2])].id
    else
        return [call], 1
    end
end

_desplat(::TupleCtx, entry) = [entry], 1
function _desplat(ctx::TupleCtx, call::Ghost.Call)
    if call.fn == Core._apply_iterate
        f = call.args[2]
        args = call.args[3:end]
        new_calls = Ghost.Call[]
        new_args = mapreduce(vcat, args) do arg
            expanded, tuple_args = ctx.splat_map[arg]
            expanded && return tuple_args
            new_tuple_args = map(1:length(tuple_args)) do i
                index_call = Ghost.mkcall(getindex, arg, i)
                push!(new_calls, index_call)
                return Ghost.Variable(index_call)
            end
            return new_tuple_args
        end

        push!(new_calls, Ghost.mkcall(f, new_args...))

        return new_calls, length(new_calls)
    else
        return [call], 1
    end
end

_squash_tuple_index(::TupleCtx, entry) = [entry], 1
function _squash_tuple_index(ctx::TupleCtx, call::Ghost.Call)
    if call.fn == tuple
        return [], nothing
    elseif call.fn == Base.indexed_iterate && haskey(ctx.tuple_map, call.args[1])
        return [], nothing
    else
        return [call], 1
    end
end

# TODO: do we need macros for defining primitive operations?
# macro operator(ex)
#     @capture(ex, fdef_ => optype_(opargs__)) ||
#         error("Cannot parse expression $ex in @simulatable. Expected: f(arg1, arg2, ...) => Operator(oparg1, oparg2, ...)")
#     @capture(fdef, f_(args__)) || error("Cannot parse expression $f in @simulatable. Expected: f(arg1, arg2, ...)")
#     argsyms = map(x -> splitarg(x)[1], args)
#     argtypes = map(x -> splitarg(x)[2], args)

#     return quote
#     end
# end
