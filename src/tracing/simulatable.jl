"""
    SimulatableContext

Used by BitSAD's simulation engine to track bit-level returns
and previously transformed calls.

# Fields
- `popmap`: a map from the original call to the simulated bit computation
- `opmap`: a "reverse" map from a function + arguments to returned `Ghost.Variable`
"""
struct SimulatableContext
    # map from original variable to popped variable
    popmap::LittleDict{Ghost.Variable, Ghost.Variable}
    # map from signatures to variable bindings
    opmap::Dict{Tuple, Ghost.Variable}
    # map from broadcasted variable to materialized call variable
    materializes::Vector{Ghost.Call}
    # results record
    results::Vector{Ghost.Variable}
end
SimulatableContext() =
    SimulatableContext(LittleDict{Ghost.Variable, Vector{Ghost.Variable}}(),
                       Dict{Tuple, Ghost.Variable}(),
                       Ghost.Call[],
                       Ghost.Variable[])

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
    replace!(m -> tape[get(subs, Ghost.Variable(m), Ghost.Variable(m))], tape.c.materializes)
    replace!(r -> get(subs, r, r), tape.c.results)
end

# after a call is transformed and the rebound variables are assigned
# update the SimulatableContext to track the bit-level returns
function _update_ctx!(ctx::SimulatableContext, vars)
    if _issimulatable(vars[1])
        if vars[1] isa Ghost.Input && length(vars) > 1
            ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[2])
        elseif vars[1] isa Ghost.Call && _isbcast(vars[1].fn) && length(vars) > 1
            isresult = Int(Ghost.Variable(vars[1]) ∈ ctx.results)
            ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[end - isresult])
            ctx.popmap[Ghost.Variable(vars[2])] = Ghost.Variable(vars[end - isresult])
            push!(ctx.materializes, vars[2])
        elseif vars[1] isa Ghost.Call && length(vars) > 1
            isresult = Int(Ghost.Variable(vars[1]) ∈ ctx.results)
            ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[end - isresult])
        # elseif vars[1] isa Ghost.Call # identity replacement
        #     ctx.popmap[Ghost.Variable(vars[1])] = vars[1].args[1]
        end
    elseif (vars[1] isa Ghost.Call) &&
           (vars[1].fn == getproperty) &&
           (_gettapeval(vars[1]) isa SBitstreamLike)
        ctx.popmap[Ghost.Variable(vars[1])] = Ghost.Variable(vars[2])
    end
    foreach(vars) do var
        (var isa Ghost.Call) && push!(ctx.opmap, (var.fn, var.args...) => Ghost.Variable(var))
    end
end

# record which calls compute outputs
# this is tape.result or
# if tape.result is the output of tuple(...)
# then it is all the entries referenced by tuple
function _record_results!(tape::Ghost.Tape{SimulatableContext})
    if tape[tape.result].fn == tuple
        foreach(tape[tape.result].args) do arg
            if tape[arg] == Base.materialize
                push!(tape.c.results, tape[arg].args[1])
            else
                push!(tape.c.results, arg)
            end
        end
    elseif tape[tape.result].fn == Base.materialize
        push!(tape.c.results, tape[tape.result].args[1])
    else
        push!(tape.c.results, tape.result)
    end
end

# pop a new bit for each argument
# unless that bit has already been popped
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

# for broadcasted operations, wrap `SBit` like a scalar
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

# how we transform unbroadcasted operations
# when the simulatable is a single object
function _unbroadcasted_transform(ctx, call, sim)
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, call.args)
    # evaluate simulator on popped bits
    bit = Ghost.mkcall(sim, popbits...)
    # push resulting bits onto bitstream
    if Ghost.Variable(call) ∈ ctx.results
        psh = [Ghost.mkcall(setbit!, Ghost.Variable(call), Ghost.Variable(bit))]
    else
        psh = []
    end

    return [call, popcalls..., bit, psh...], 1
end

# how we transform unbroadcasted operations
# when the simulatable is an array of simulatables
function _unbroadcasted_transform(ctx, call, sims::AbstractArray)
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, call.args)
    # evaluate simulator on popped bits
    # evaluate simulators element-wise on popped bits
    wrapcalls, wrapbits = _wrap_bcast_bits(popbits)
    bits = Ghost.mkcall(Base.broadcasted, (f, a...) -> f(a...), sims, wrapbits...)
    matbits = Ghost.mkcall(Base.materialize, Ghost.Variable(bits))
    # push resulting bits onto bitstream
    if Ghost.Variable(call) ∈ ctx.results
        psh = [Ghost.mkcall(setbit!, Ghost.Variable(call), Ghost.Variable(matbits))]
    else
        psh = []
    end

    return [call, popcalls..., wrapcalls..., bits, matbits, psh...], 1
end

# how we transform broadcasted operations
# when the simulatable is a single object
function _broadcasted_transform(ctx, call, sim)
    # ignore first (function) arg of broadcasted
    args = call.args[2:end]
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, args)
    # materialize broadcasted
    mat = Ghost.mkcall(Base.materialize, Ghost.Variable(call))
    # ctx.materialize_map[Ghost.Variable(call)] = Ghost.Variable(mat)
    # evaluate simulator on popped bits
    bit = Ghost.mkcall(sim, popbits...)
    # push resulting bits onto bitstream
    if Ghost.Variable(call) ∈ ctx.results
        psh = [Ghost.mkcall(setbit!, Ghost.Variable(mat), Ghost.Variable(bit))]
    else
        psh = []
    end

    return [call, mat, popcalls..., bit, psh...], 2
end

# how we transform broadcasted operations
# when the simulatable is an array of simulatables
function _broadcasted_transform(ctx, call, sims::AbstractArray)
    # ignore first (function) arg of broadcasted
    args = call.args[2:end]
    # insert calls to pop bits from the args
    popcalls, popbits = _popcalls(ctx, args)
    # materialize broadcasted
    mat = Ghost.mkcall(Base.materialize, Ghost.Variable(call))
    # ctx.materialize_map[Ghost.Variable(call)] = Ghost.Variable(mat)
    # evaluate simulators element-wise on popped bits
    wrapcalls, wrapbits = _wrap_bcast_bits(popbits)
    bits = Ghost.mkcall(Base.broadcasted, (f, a...) -> f(a...), sims, wrapbits...)
    matbits = Ghost.mkcall(Base.materialize, Ghost.Variable(bits))
    # push resulting bits onto bitstreams
    if Ghost.Variable(call) ∈ ctx.results
        psh = [Ghost.mkcall(setbit!, Ghost.Variable(mat), Ghost.Variable(matbits))]
    else
        psh = []
    end

    return [call, mat, popcalls..., wrapcalls..., bits, matbits, psh...], 2
end

# check if the function is broadcasted and
# call the appropriate transform
_handle_bcast_and_transform(ctx, call, sim) =
    _isbcast(call.fn) ? _broadcasted_transform(ctx, call, sim) :
                        _unbroadcasted_transform(ctx, call, sim)

# pop bits for getproperty
_getproperty_transform(ctx, call) = haskey(ctx.opmap, (call.fn, call.args...)) ?
    ([], ctx.opmap[(call.fn, call.args...)].id) :
    ([call, Ghost.mkcall(getbit, Ghost.Variable(call))], 1)

# the main tranform for simulatables
_simtransform(ctx, input::Ghost.Input) =
    _gettapeval(Ghost.Variable(input)) isa SBitstreamLike ?
        ([input, Ghost.mkcall(getbit, Ghost.Variable(input))], 1) :
        ([input], 1)
function _simtransform(ctx, call::Ghost.Call)
    # if this call is a materialize and it has already been materialized
    # then delete it
    if call.fn == Base.materialize
        id = findfirst(x -> _getid(x) == _getid(call.args[1]), ctx.materializes)
        if !isnothing(id)
            return [], ctx.materializes[id]
        end
    end

    # if this is a getproperty call that returns a SBitstreamLike
    # then pop the bits
    (call.fn == getproperty) && (_gettapeval(call) isa SBitstreamLike) &&
        return _getproperty_transform(ctx, call)

    # if the args don't contain SBitstreamLike, then skip
    sig = Ghost.get_type_parameters(Ghost.call_signature(call.fn, _gettapeval.(call.args)...))
    is_simulatable_primitive(sig...) || return [call], 1

    # get the simulator for this call signature
    sim = getsimulator(call.fn, map(arg -> _gettapeval(arg), call.args)...)

    # skip nosims
    isnothing(sim) && return [call], 1

    # if call has already been transformed,
    #  then delete this call and rebind to the transformed call
    haskey(ctx.opmap, (call.fn, call.args...)) && return [], ctx.opmap[(call.fn, call.args...)].id

    # otherwise, transform this call while handling broadcasting
    return _handle_bcast_and_transform(ctx, call, sim)
end

# redirection for popping only SBitstreamLike arguments
getbit(x) = x
getbit(x::SBitstreamLike) = pop!.(x)
# redirection for pushing only SBitstreamLike arguments
setbit!(x::SBitstream, bit) = push!(x, bit)
setbit!(x::AbstractArray{<:SBitstream}, bits) = push!.(x, bits)

"""
    is_simulatable_primitive(ftype::Type, argtypes::Type...)

Return true if calling a callable of type `ftype` on arguments
of types `argtypes` is a BitSAD simulatable primitive operator.

Custom operators should overload [`BitSAD.is_trace_primitive`](#) before this function.
`is_simulatable_primitive` should only be overloaded if the primitive behavior is
different for only simulation. Defaults to `is_trace_primitive`.
"""
is_simulatable_primitive(sig...) = is_trace_primitive(sig...)

"""
    getsimulator(f, args...)

Return a new instance of the simulatable operator for `f(args...)`.

Custom operators should overload this function and
define [`BitSAD.is_simulatable_primitive`](#).
"""
function getsimulator end

"""
    simulator(f, args...)

Return a simulatable `Ghost.Tape` for `f(args...)`.
End-users should use [`simulatable`](#) instead.
"""
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
    _record_results!(tape)
    transform!(_simtransform, _update_ctx!, tape)

    return tape
end

"""
    simulatable(f, args...)

Return a simulatable variation of `f(args...)` that emulates the bit-level
operations for [`SBitstream`](#) variables.
The returned function, call it `sim`, can be called via `sim(f, args...)`.

This is done by recursively tracing the execution of `f(args...)` then replacing
each primitive simulatable operation with a simulatable operator.
"""
simulatable(f, args...) = Ghost.compile(simulator(f, args...))

"""
    show_simulatable(f, args...)

Print the simulatable program returned by [`simulatable`](#).
"""
show_simulatable(f, args...) = Ghost.to_expr(simulator(f, args...))

"""
    @nosim f(x, y::T, ...) [kwargs=false]

Mark a function call of the form `f(x, y::T, ...)` as a simulation primitive.
This will prevent BitSAD's simulation engine for recursing this function,
and instead use the return value of `f` directly (without simulating it).
Arguments may or may not have a type specified.

Set `kwargs=true` if `f` accepts keyword arguments.
Note that the type and name of keywords cannot be specified.

If `f(x, y, ...)` has a corresponding simulatable operator,
then define [`BitSAD.getsimulator`](#) for `f`.
"""
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
                                    ::Any,
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
