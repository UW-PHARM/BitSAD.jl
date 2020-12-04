struct TraceCall
    inputs::Vector{Net}
    outputs::Vector{Net}
    operator::Symbol
    optype::Type
    broadcasted::Bool
    subtrace::Vector{TraceCall}
end

const Trace = Vector{TraceCall}

Base.show(io::IO, c::TraceCall) =
    print(io, "TraceCall($(length(c.subtrace)))($(c.inputs) => $(c.outputs))")
Base.show(io::IO, ::MIME"text/plain", c::TraceCall) = print(io, strip("""
    TraceCall $(c.operator)::$(c.optype) w/ $(length(c.subtrace))-length subtrace:
        Broadcasted: $(c.broadcasted)
        Inputs:
            $(map(i -> "$i\n        ", c.inputs)...)
        Outputs:
            $(map(i -> "$i\n        ", c.outputs)...)
    """))

Base.show(io::IO, t::Trace) =
    print(io, "Trace($(length(t)) nodes)")
Base.show(io::IO, ::MIME"text/plain", t::Trace) = print(io, strip("""
    Trace($(length(t)) nodes):
      $(map(i -> "$i\n  ", t)...)
    """))

hassubtrace(c::TraceCall) = !isempty(c.subtrace)

@kwdef mutable struct HardwareState
    current_trace::Trace = Trace()
    trace_stack::Vector{Trace} = [current_trace]
    output_map::Dict{Tuple{Bool, Vararg{String}}, String} = Dict{Tuple{Bool, Vararg{String}}, String}()
    struct_map::Dict{String, Int} = Dict{String, Int}()
end

exists(state::HardwareState, isbroadcast, f, args...) = haskey(state.output_map, (isbroadcast, f, args...))

function set_output!(state::HardwareState, output, isbroadcast, f, args...)
    state.output_map[(isbroadcast, f, args...)] = output

    return state
end

get_output(state::HardwareState, isbroadcast, f, args...) = state.output_map[(isbroadcast, f, args...)]

function get_structname!(state::HardwareState, ::T) where T
    fname = lowercase(string(nameof(T)))
    if haskey(state.struct_map, fname)
        state.struct_map[fname] += 1
        return "$(fname)$(state.struct_map[fname])"
    else
        state.struct_map[fname] = 0
        return "$(fname)0"
    end
end
        

Cassette.@context HardwareCtx

_isstruct(f::T) where T = isstructtype(T) && !(f isa Function)

istraceprimitive(ctx::HardwareCtx, f, args...) =
    istraceprimitive(Cassette.untag(f, ctx), map(arg -> Cassette.untag(arg, ctx), args)...)
istraceprimitive(f, args...) = _isstruct(f) ? true : false

# macro trace_primitive(f, args...)
#     return quote
#         # Cassette.overdub(ctx::HardwareCtx, ::typeof($(esc(f))), $(esc.(args)...)) =
#         #     Cassette.fallback($(esc(f)), $(esc.(args)...))
#         HW.istraceprimitive(::typeof($(esc(f))), $(esc.(args)...)) = true
#     end
# end

function enter!(ctx::HardwareCtx, trace::Trace, f, args...; isbroadcast = false)
    inputs = [Net(name = namify!(arg, ctx),
                  jltype = Cassette.untagtype(typeof(arg), typeof(ctx)),
                  size = netsize(Cassette.untag(arg, ctx)))
              for arg in args]
    outputs = Net[]
    operator = Symbol(namify!(f, ctx))
    optype = Cassette.untagtype(typeof(f), typeof(ctx))
    trace_call = TraceCall(inputs, outputs, operator, optype, isbroadcast, Trace())
    push!(trace, trace_call)

    return trace_call.subtrace
end

function exit!(ctx::HardwareCtx, trace::Trace, output)
    push!(trace[end].outputs, Net(name = namify!(output, ctx),
                                  jltype = Cassette.untagtype(typeof(output), typeof(ctx)),
                                  size = netsize(Cassette.untag(output, ctx))))

    return trace[end]
end

Cassette.metadatatype(::Type{<:HardwareCtx}, ::DataType) = String

namify!(x, ctx) = Cassette.hasmetadata(x, ctx) ? Cassette.metadata(x, ctx) :
                    _isstruct(x) ? get_structname!(ctx.metadata, Cassette.untag(x, ctx)) :
                                   string(Cassette.untag(x, ctx))

generate_output_name(f, args) =
    "net_$(f)_$(first(args))$(map(arg -> "_" * arg, Base.tail(args))...)"

compress_name(name) =
    mapreduce(x -> startswith(x, ".") ? first(x, 2) : first(x, 1), *, split(replace(name, "net_" => ""), "_"))

function select_output_name!(ctx::HardwareCtx, f, args...; isbroadcast = false)
    f_name = isbroadcast ? "." * namify!(f, ctx) : namify!(f, ctx)
    arg_names = namify!.(args, Ref(ctx))
    if exists(ctx.metadata, isbroadcast, f_name, arg_names...)
        return get_output(ctx.metadata, isbroadcast, f_name, arg_names...)
    else
        name = generate_output_name(compress_name(f_name), compress_name.(arg_names))
        set_output!(ctx.metadata, name, isbroadcast, f_name, arg_names...)

        return name
    end
end

function Cassette.prehook(ctx::HardwareCtx, f, args...)
    subtrace = enter!(ctx, ctx.metadata.current_trace, f, args...)
    !istraceprimitive(ctx, f, args...) && push!(ctx.metadata.trace_stack, subtrace)
    ctx.metadata.current_trace = ctx.metadata.trace_stack[end]
end

function Cassette.posthook(ctx::HardwareCtx, output, f, args...)
    if !istraceprimitive(ctx, f, args...)
        println("Popping $(namify!(f, ctx))")
        removed_trace = pop!(ctx.metadata.trace_stack)
        ctx.metadata.current_trace = isempty(ctx.metadata.trace_stack) ? removed_trace :
                                                                         ctx.metadata.trace_stack[end]
    end
    exit!(ctx, ctx.metadata.current_trace, output)
end

function _overdub(ctx::HardwareCtx, f, args...; isbroadcast = false)
    unwrapped_f = Cassette.untag(f, ctx)
    unwrapped_args = map(arg -> Cassette.untag(arg, ctx), args)
    println("Calling $unwrapped_f($(unwrapped_args...))")
    if istraceprimitive(unwrapped_f, unwrapped_args...)
        result = unwrapped_f(unwrapped_args...)
        name = select_output_name!(ctx, f, args...; isbroadcast = isbroadcast)

        return Cassette.tag(result, ctx, name)
    else 
        return Cassette.recurse(ctx, f, args...)
    end
end
Cassette.overdub(ctx::HardwareCtx, f, args...) = _overdub(ctx, f, args...)


## Broadcasting hooks

execute_and_tag(ctx::HardwareCtx, f, arg) =
    Cassette.tag(Cassette.fallback(ctx, Cassette.untag(f, ctx), Cassette.untag(arg, ctx)), ctx, namify!(arg, ctx))

function execute_and_tag(ctx::HardwareCtx, f,  args...)
    untagged_args = map(arg -> Cassette.untag(arg, ctx), args)
    output_args = Cassette.fallback(ctx, Cassette.untag(f, ctx), untagged_args...)

    return map((out_arg, arg) -> Cassette.tag(out_arg, ctx, namify!(arg, ctx)), output_args, args)
end

_materialize(ctx, x) = Cassette.tag(Base.Broadcast.materialize(Cassette.untag(x, ctx)), ctx, namify!(x, ctx))

function Cassette.prehook(ctx::HardwareCtx, ::typeof(Base.broadcasted), f, args...)
    materialized_args = map(arg -> _materialize(ctx, arg), args)
    subtrace = enter!(ctx, ctx.metadata.current_trace, f, materialized_args...; isbroadcast = true)
    !istraceprimitive(ctx, f, materialized_args...) && push!(ctx.metadata.trace_stack, subtrace)
    ctx.metadata.current_trace = ctx.metadata.trace_stack[end]
end

function Cassette.posthook(ctx::HardwareCtx, output, ::typeof(Base.broadcasted), f, args...)
    materialized_args = map(arg -> _materialize(ctx, arg), args)
    materialized_output = _materialize(ctx, output)
    Cassette.posthook(ctx, materialized_output, f, materialized_args...)
end

function Cassette.overdub(ctx::HardwareCtx, ::typeof(Base.broadcasted), f, args...)
    arg_names = namify!.(args, Ref(ctx))
    unwrapped_args = map(arg -> Cassette.untag(arg, ctx), args)
    element_args = map((arg, name) -> Cassette.tag(first(arg), ctx, name), unwrapped_args, arg_names)
    element_result = _overdub(ctx, f, element_args...; isbroadcast = true)
    result = Base.broadcasted(Cassette.untag(f, ctx), unwrapped_args...)

    return Cassette.tag(result, ctx, namify!(element_result, ctx))
end

## Primitives
#   don't recurse these calls

Cassette.prehook(ctx::HardwareCtx, ::typeof(Base.materialize), args...) = nothing
Cassette.posthook(ctx::HardwareCtx, output, ::typeof(Base.materialize), args...) = nothing
Cassette.overdub(ctx::HardwareCtx, ::typeof(Base.materialize), arg) = execute_and_tag(ctx, Base.materialize, arg)

Cassette.prehook(ctx::HardwareCtx, ::typeof(promote), args...) = nothing
Cassette.posthook(ctx::HardwareCtx, output, ::typeof(promote), args...) = nothing
Cassette.overdub(ctx::HardwareCtx, ::typeof(promote), args...) = execute_and_tag(ctx, promote, args...)

Cassette.prehook(ctx::HardwareCtx, ::typeof(convert), args...) = nothing
Cassette.posthook(ctx::HardwareCtx, output, ::typeof(convert), args...) = nothing
Cassette.overdub(ctx::HardwareCtx, ::typeof(convert), args...) = execute_and_tag(ctx, convert, args...)

Cassette.prehook(ctx::HardwareCtx, ::typeof(Core._apply_iterate), args...) = nothing
Cassette.posthook(ctx::HardwareCtx, output, ::typeof(Core._apply_iterate), args...) = nothing
Cassette.overdub(ctx::HardwareCtx, ::typeof(Core._apply_iterate), args...) =
    execute_and_tag(ctx, Core._apply_iterate, args...)