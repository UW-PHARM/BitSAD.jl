struct SimulatableContext
    # map from original variable to popped variable
    popmap::Dict{Ghost.Variable, Ghost.Variable}
    # map from signatures to variable bindings
    opmap::Dict{Tuple, Ghost.Variable}
end
SimulatableContext() = SimulatableContext(Dict{Ghost.Variable, Vector{Ghost.Variable}}(),
                                          Dict{Tuple, Ghost.Variable}())

function Ghost.rebind_context!(tape::Ghost.Tape{SimulatableContext}, subs::Dict)
    replace!(tape.c.popmap) do kv
        old_var, new_var = kv
        old_var = get(subs, old_var, old_var)
        new_var = get(subs, new_var, new_var)

        return old_var => new_var
    end
    replace!(tape.c.opmap) do kv
        sig, var = kv
        newout = get(subs, var, var)
        newargs = [get(subs, arg, arg) for arg in Base.tail(sig)]

        return (sig[1], newargs...) => newout
    end
end

function _update_ctx!(ctx::SimulatableContext, vars)
    if _issimulatable(vars[1])
        if vars[1] isa Ghost.Input && length(vars) > 1
            ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[2])
        elseif vars[1] isa Ghost.Call && length(vars) > 1
            ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[end - 1])
        # elseif vars[1] isa Ghost.Call # identity replacement
        #     ctx.popmap[Ghost.Variable(vars[1])] = vars[1].args[1]
        end
    end
    foreach(vars) do var
        (var isa Ghost.Call) && push!(ctx.opmap, (var.fn, var.args...) => Ghost.Variable(var))
    end
end

function _popcalls(ctx, args)
    calls = []
    new_args = []
    foreach(args) do arg
        if _gettapeval(arg) isa SBitstreamLike
            if haskey(ctx.popmap, arg)
                push!(new_args, ctx.popmap[arg])
            else
                popcall = Ghost.mkcall(getbit, arg)
                push!(calls, popcall)
                push!(new_args, Ghost.Variable(popcall))
            end
        else
            push!(new_args, arg)
        end
    end

    return calls, new_args
end

function _unbroadcasted_transform(ctx, call, mksim)
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, call.args)
    # create a new simulator instance
    sim = mksim(call.args...)
    # evaluate simulator on popped bits
    bit = Ghost.mkcall(sim, popbits...)
    # push resulting bits onto bitstream
    psh = Ghost.mkcall(setbit!, Ghost.Variable(call), Ghost.Variable(bit))

    return [call, popcalls..., bit, psh], 1
end

function _broadcasted_transform(ctx, call, mksim)
    # ignore first (function) arg of broadcasted
    args = call.args[2:end]
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, args)
    # materialize broadcasted
    mat = Ghost.mkcall(Base.materialize, Ghost.Variable(call))
    # create a new simulator instance
    sim = mksim(args...)
    # evaluate simulator on popped bits
    bit = Ghost.mkcall(sim, popbits...)
    # push resulting bits onto bitstream
    psh = Ghost.mkcall(setbit!, Ghost.Variable(mat), Ghost.Variable(bit))

    return [call, mat, popcalls..., bit, psh], 1
end

function _broadcasted_transform(ctx, call, mksims::AbstractArray)
    # ignore first (function) arg of broadcasted
    args = call.args[2:end]
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, args)
    # materialize broadcasted
    mat = Ghost.mkcall(Base.materialize, Ghost.Variable(call))
    # create multiple instances of simulator
    sims = map((f, a...) -> f(a...), mksims, args...)
    # evaluate simulators element-wise on popped bits
    bits = Ghost.mkcall(map, (f, a...) -> f(a...), sims, popbits...)
    # push resulting bits onto bitstreams
    psh = Ghost.mkcall(setbit!, Ghost.Variable(mat), Ghost.Variable(bits))

    return [call, mat, popcalls..., bits, psh], 1
end

_handle_bcast_and_transform(ctx, call, mksim) =
    _isbcast(call.fn) ? _broadcasted_transform(ctx, call, mksim) :
                        _unbroadcasted_transform(ctx, call, mksim)

_simtransform(ctx, input::Ghost.Input) =
    _gettapeval(Ghost.Variable(input)) isa SBitstreamLike ?
        ([input, Ghost.mkcall(getbit, Ghost.Variable(input))], 1) :
        ([input], 1)
function _simtransform(ctx, call::Ghost.Call)
    # if the args don't contain SBitstreamLike, then skip
    _issimulatable(call) || return [call], 1

    # if call has already been transformed,
    #  then delete this call and rebind to the transformed call
    # otherwise, transform this call while handling broadcasting
    if haskey(ctx.opmap, (call.fn, call.args...))
        return [], ctx.opmap[(call.fn, call.args...)].id
    else
        # get the simulator for this call signature
        mksim = getsimulator(call.fn, map(arg -> _gettapeval(arg), call.args)...)
        return _handle_bcast_and_transform(ctx, call, mksim)
    end
end

getbit(x) = x
getbit(x::SBitstreamLike) = pop!.(x)

setbit!(x::SBitstream, bit) = push!(x, bit)
setbit!(x::AbstractArray{<:SBitstream}, bits) = push!.(x, bits)

is_simulatable_primitive(sig...) = is_trace_primitive(sig...)

function simulatable(f, args...)
    tape = trace(f, args...;
                 is_primitive = is_simulatable_primitive,
                 ctx = SimulatableContext())
    transform!(_squash_binary_vararg, tape)
    transform!(_simtransform, _update_ctx!, tape)

    return tape
end

## Utilities for defining simulatable operators

function apply_binary_to_vararg(ops)
    function apply_ops(xs...)
        acc = first(xs)
        for (op, x) in zip(ops, Base.tail(xs))
            acc = op(acc, x)
        end

        return acc
    end

    return apply_ops
end
