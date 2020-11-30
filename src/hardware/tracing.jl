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

@kwdef mutable struct HardwareState
    current_trace::Trace = Trace()
    trace_stack::Vector{Trace} = [current_trace]
    output_map::Dict{Tuple{Vararg{String}}, String} = Dict{Tuple{Vararg{String}}, String}()
end

exists(state::HardwareState, f, args...) = haskey(state.output_map, (f, args...))

function set_output!(state::HardwareState, output, f, args...)
    state.output_map[(f, args...)] = output

    return state
end

get_output(state::HardwareState, f, args...) = state.output_map[(f, args...)]

Cassette.@context HardwareCtx

istraceprimitive(ctx::HardwareCtx, f, args...) =
    istraceprimitive(Cassette.untag(f, ctx), map(arg -> Cassette.untag(arg, ctx), args)...)
istraceprimitive(f, args...) = (f isa Function) ? false : true

function enter!(ctx::HardwareCtx, trace::Trace, f, args...; isbroadcast = false)
    inputs = [Net(name = namify(arg, ctx),
                  jltype = Cassette.untagtype(typeof(arg), typeof(ctx)),
                  size = netsize(Cassette.untag(arg, ctx)))
              for arg in args]
    outputs = Net[]
    operator = Symbol(namify(f, ctx))
    optype = Cassette.untagtype(typeof(f), typeof(ctx))
    trace_call = TraceCall(inputs, outputs, operator, optype, isbroadcast, Trace())
    push!(trace, trace_call)

    return trace_call.subtrace
end

function exit!(ctx::HardwareCtx, trace::Trace, output)
    push!(trace[end].outputs, Net(name = namify(output, ctx),
                                  jltype = Cassette.untagtype(typeof(output), typeof(ctx)),
                                  size = netsize(Cassette.untag(output, ctx))))

    return trace[end]
end

Cassette.metadatatype(::Type{<:HardwareCtx}, ::DataType) = String

namify(x, ctx) = Cassette.hasmetadata(x, ctx) ? Cassette.metadata(x, ctx) : string(Cassette.untag(x, ctx))

generate_output_name(f, args) =
    "net_$(f)_$(first(args))$(map(arg -> "_" * arg, Base.tail(args))...)"

compress_name(name) = mapreduce(x -> first(x, 1), *, split(replace(name, "net_" => ""), "_"))

function select_output_name!(ctx::HardwareCtx, f, args...)
    f_name = namify(f, ctx)
    arg_names = namify.(args, Ref(ctx))
    if exists(ctx.metadata, f_name, arg_names...)
        return get_output(ctx.metadata, f_name, arg_names...)
    else
        name = generate_output_name(compress_name(f_name), compress_name.(arg_names))
        set_output!(ctx.metadata, name, f_name, arg_names...)

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
        removed_trace = pop!(ctx.metadata.trace_stack)
        ctx.metadata.current_trace = isempty(ctx.metadata.trace_stack) ? removed_trace :
                                                                         ctx.metadata.trace_stack[end]
    end
    exit!(ctx, ctx.metadata.current_trace, output)
end

function Cassette.overdub(ctx::HardwareCtx, f, args...)
    unwrapped_f = Cassette.untag(f, ctx)
    unwrapped_args = map(arg -> Cassette.untag(arg, ctx), args)
    println("Calling $unwrapped_f($(unwrapped_args...))")
    if istraceprimitive(unwrapped_f, unwrapped_args...)
        result = unwrapped_f(unwrapped_args...)
    else 
        result = Cassette.untag(Cassette.recurse(ctx, f, args...), ctx)
    end

    name = select_output_name!(ctx, f, args...)
    return Cassette.tag(result, ctx, name)
end

function Cassette.prehook(ctx::HardwareCtx, ::typeof(Base.broadcasted), f, args...)
    subtrace = enter!(ctx, ctx.metadata.current_trace, f, args...; isbroadcast = true)
    !istraceprimitive(ctx, f, args...) && push!(ctx.metadata.trace_stack, subtrace)
    ctx.metadata.current_trace = ctx.metadata.trace_stack[end]
end

Cassette.posthook(ctx::HardwareCtx, output, ::typeof(Base.broadcasted), f, args...) =
    Cassette.posthook(ctx, output, f, args...)

Cassette.overdub(ctx::HardwareCtx, ::typeof(Base.materialize), args...) =
    Cassette.fallback(ctx, Base.materialize, args...)

macro trace_primitive(f, args...)
    return quote
        # Cassette.overdub(ctx::HardwareCtx, ::typeof($(esc(f))), $(esc.(args)...)) =
        #     Cassette.fallback($(esc(f)), $(esc.(args)...))
        HW.istraceprimitive(::typeof($(esc(f))), $(esc.(args)...)) = true
    end
end