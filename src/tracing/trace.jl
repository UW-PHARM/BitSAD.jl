_typeof(f) = typeof(f)
_typeof(T::Type) = T

"""
    is_trace_primitive(ftype::Type, argtypes::Type...)

Return true if calling a callable of type `ftype` on arguments
of types `argtypes` is a BitSAD primitive operator.

Custom operators should overload this function.
Defaults to false.
"""
is_trace_primitive(x...) = false

## Default primitives

is_trace_primitive(::Type{typeof(LinearAlgebra.norm)},
                   ::Type{<:AbstractVector},
                   ::Type{<:Any}) = true

"""
    trace(f, args; is_primitive = is_trace_primitive,
                   submodules = [],
                   ctx = Dict{Any, Any}())

Trace the function call `f(args...)` and return the `Ghost.Tape`.
Callables in `submodules` are considered primitive operators.

This function is not meant to be called by users.
Users should use [`simulatable`](#) or [`generatehw`](#) instead.
"""
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

"""
    transform!(f, [fctx,] tape::Ghost.Tape)

Transform `tape` by applying `f` to each entry in the tape.

`f(tape.ctx, entry)` cannot manipulate `tape` directly.
Instead, `f` should return a tuple of the form `([calls...], idx)`
where `[calls...]` is a vector of tape entries that should replace `entry`.
`idx` specifies that references to `entry` in `tape` should be rebound to
`calls[idx]`.
If `calls` is empty, then `entry` is deleted from the tape,
and references to it are rebound to `idx`.
Note that if `entry isa Ghost.Input`, then it cannot be deleted from `tape`.

`fctx(tape.ctx, calls)` can be used to update `tape.ctx`.
`calls` is the same list of entries returned by `f` except
that the ID for each entry in `calls` is the ID *after* being rebound in `tape`.
If `calls` was empty, then `fctx` is not called.
If not specified, `fctx` is a no-op.
"""
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

"""
    squashable(ftype::Type)

Return true if a callable of type `ftype` is a
"squashable" 2-arg function.
Defaults to false.

Functions like `+` are n-arg functions in Julia,
but most hardware designers think of them as 2-arg.
When `squashable` returns true, BitSAD's tracing engine will
"squash" a single n-arg call into nested 2-arg calls.
"""
squashable(x) = false
for op in (:+, :-, :*, :/, :÷)
    @eval squashable(::typeof($op)) = true
end

# transform a call like `f(args...)` into
# nested 2-arg calls to `f` when `squashable(f)` is true
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

# eagerly materialize broadcasting
# while still maintaining the original call on the stack
# removing the call from the stack will cause issues with contexts
_unbroadcast(ctx, entry) = [entry], 1
_unbroadcast(ctx, call::Ghost.Call{typeof(Base.broadcasted)}) =
    ([call, Ghost.mkcall(Base.materialize, Ghost.Variable(call))], 2)

## TUPLE TRACKING
# the remaining code is used to re-route
#  multiple return value handling and splatting in Julia
# we record calls to `tuple` and `ntuple` so that references
#  to splatting or `indexed_iterate`-ing those tuples just
#  directly uses the values that made up the tuple
# to use this functionality,
# 1. make sure the tape has a `TupleCtx`
# 2. apply the `_record_tuples_and_splats` transform
# 3. apply the `_reroute_tuple_index` transform
# 4. apply the `_desplat` transform
# (see `generatehw` for an example)

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
            op = _gettapeop(arg)
            if (op isa Ghost.Call) && ((op.fn == tuple) || (op.fn == ntuple))
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

            return [], _getid(tuple_args[indexed_itr[2]])
        else
            return [], nothing
        end
    elseif call.fn == Base.getindex && haskey(ctx.tuple_map, call.args[1])
        tuple_args = ctx.tuple_map[call.args[1]]

        return [], _getid(tuple_args[_gettapeval(call.args[2])])
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

# _squash_tuple_index(::TupleCtx, entry) = [entry], 1
# function _squash_tuple_index(ctx::TupleCtx, call::Ghost.Call)
#     if call.fn == tuple
#         return [], nothing
#     elseif call.fn == Base.indexed_iterate && haskey(ctx.tuple_map, call.args[1])
#         return [], nothing
#     else
#         return [call], 1
#     end
# end
