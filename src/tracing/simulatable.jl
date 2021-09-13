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
        elseif vars[1] isa Ghost.Call && _isbcast(vars[1].fn) && length(vars) > 1
            ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[end - 1])
            ctx.popmap[Ghost.Variable(vars[2])] = Ghost.Variable(vars[end - 1])
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

function _wrap_bcast_bits(popbits)
    wrap_calls = []
    wrap_bits = []
    for bit in popbits
        if _gettapeval(bit) isa SBit
            call = Ghost.mkcall(Ref, bit)
            push!(wrap_calls, call)
            push!(wrap_bits, Ghost.Variable(call))
        else
            push!(wrap_bits, bit)
        end
    end

    return wrap_calls, wrap_bits
end

function _unbroadcasted_transform(ctx, call, sim)
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, call.args)
    # evaluate simulator on popped bits
    bit = Ghost.mkcall(sim, popbits...)
    # push resulting bits onto bitstream
    psh = Ghost.mkcall(setbit!, Ghost.Variable(call), Ghost.Variable(bit))

    return [call, popcalls..., bit, psh], 1
end

function _broadcasted_transform(ctx, call, sim)
    # ignore first (function) arg of broadcasted
    args = call.args[2:end]
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, args)
    # materialize broadcasted
    mat = Ghost.mkcall(Base.materialize, Ghost.Variable(call))
    # evaluate simulator on popped bits
    bit = Ghost.mkcall(sim, popbits...)
    # push resulting bits onto bitstream
    psh = Ghost.mkcall(setbit!, Ghost.Variable(mat), Ghost.Variable(bit))

    return [call, mat, popcalls..., bit, psh], 1
end

function _broadcasted_transform(ctx, call, sims::AbstractArray)
    # ignore first (function) arg of broadcasted
    args = call.args[2:end]
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, args)
    # materialize broadcasted
    mat = Ghost.mkcall(Base.materialize, Ghost.Variable(call))
    # evaluate simulators element-wise on popped bits
    wrapcalls, wrapbits = _wrap_bcast_bits(popbits)
    bits = Ghost.mkcall(Base.broadcasted, (f, a...) -> f(a...), sims, wrapbits...)
    matbits = Ghost.mkcall(Base.materialize, Ghost.Variable(bits))
    # push resulting bits onto bitstreams
    psh = Ghost.mkcall(setbit!, Ghost.Variable(mat), Ghost.Variable(matbits))

    return [call, mat, popcalls..., wrapcalls..., bits, matbits, psh], 1
end

_handle_bcast_and_transform(ctx, call, sim) =
    _isbcast(call.fn) ? _broadcasted_transform(ctx, call, sim) :
                        _unbroadcasted_transform(ctx, call, sim)

_simtransform(ctx, input::Ghost.Input) =
    _gettapeval(Ghost.Variable(input)) isa SBitstreamLike ?
        ([input, Ghost.mkcall(getbit, Ghost.Variable(input))], 1) :
        ([input], 1)
function _simtransform(ctx, call::Ghost.Call)
    # if call has already been transformed,
    #  then delete this call and rebind to the transformed call
    haskey(ctx.opmap, (call.fn, call.args...)) && return [], ctx.opmap[(call.fn, call.args...)].id

    # if the args don't contain SBitstreamLike, then skip
    sig = Ghost.get_type_parameters(Ghost.call_signature(call.fn, _gettapeval.(call.args)...))
    is_simulatable_primitive(sig...) || return [call], 1

    # otherwise, transform this call while handling broadcasting
    # get the simulator for this call signature
    sim = getsimulator(call.fn, map(arg -> _gettapeval(arg), call.args)...)
    return isnothing(sim) ? ([call], 1) : _handle_bcast_and_transform(ctx, call, sim)
end

getbit(x) = x
getbit(x::SBitstreamLike) = pop!.(x)

setbit!(x::SBitstream, bit) = push!(x, bit)
setbit!(x::AbstractArray{<:SBitstream}, bits) = push!.(x, bits)

is_simulatable_primitive(sig...) = is_trace_primitive(sig...)

function simulator(f, args...)
    # if f itself is a primitive, do a manual tape
    if is_simulatable_primitive(Ghost.get_type_parameters(Ghost.call_signature(f, args...))...)
        tape = Ghost.Tape(SimulatableContext())
        inputs = Ghost.inputs!(tape, f, args...)
        if _isstruct(f)
            tape.result = push!(tape, Ghost.mkcall(inputs...))
        else
            tape.result = push!(tape, Ghost.mkcall(f, inputs[2:end]...))
        end
    else
        tape = trace(f, args...;
                     isprimitive = is_simulatable_primitive,
                     ctx = SimulatableContext())
    end
    transform!(_squash_binary_vararg, tape)
    transform!(_simtransform, _update_ctx!, tape)

    return tape
end
simulatable(f, args...) = Ghost.compile(simulator(f, args...))
show_simulatable(f, args...) = Ghost.to_expr(simulator(f, args...))

macro nosim(ex, kws...)
    kwargs = isempty(kws) ? false :
             (kws[1].args[1] == :kwargs) ? kws[1].args[2] :
             error("Unrecognized options: $kws")
    if @capture(ex, f_(args__))
        argtypes = map(args) do arg
            @capture(arg, x_::T_) ? T : :Any
        end
        primitive_sig = [:(::Type{<:$(esc(T))}) for T in argtypes]

        if kwargs
            return quote
                BitSAD.is_simulatable_primitive(::Type{Core.kwftype(typeof($(esc(f))))},
                                                ::Type{<:Any},
                                                ::Type{typeof($(esc(f)))},
                                                $(primitive_sig...)) = true
                BitSAD.getsimulator(::Core.kwftype(typeof($(esc(f)))),
                                    ::Any
                                    ::typeof($(esc(f))),
                                    $(esc.(args)...)) = nothing
            end
        else
            return quote
                BitSAD.is_simulatable_primitive(::Type{typeof($(esc(f)))}, $(primitive_sig...)) = true
                BitSAD.getsimulator(::typeof($(esc(f))), $(esc.(args)...)) = nothing
            end
        end
    else
        error("Cannot parse @nosim $ex (expects @nosim f(arg1, arg2::T, ...).")
    end
end
