_typeof(f) = typeof(f)
_typeof(T::Type) = T

is_trace_primitive(x...) = false

function trace(f, args...; is_primitive = is_trace_primitive, submodules = [], ctx = Dict{Any, Any}())
    primitive_sigs =
        Ghost.FunctionResolver{Bool}([Tuple{_typeof(f), Vararg} => true for f in submodules])
    is_primitive_or_submodule(sig) =
        Ghost.is_primitive(sig) ||
        is_primitive(Ghost.get_type_parameters(sig)...) ||
        sig ∈ primitive_sigs
    _, tape = Ghost.trace(f, args...; is_primitive = is_primitive_or_submodule, ctx = ctx)

    return tape
end

function transform!(f, fctx, tape::Ghost.Tape)
    local entry, rebind_to
    itr = iterate(tape)
    @debug tape
    while !isnothing(itr)
        entry, idx = itr
        @debug entry
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
        @debug tape
        itr = iterate(tape, idx)
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
