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
end

exists(state::HardwareState, isbroadcast, f, args...) = haskey(state.output_map, (isbroadcast, f, args...))

function set_output!(state::HardwareState, output, isbroadcast, f, args...)
    state.output_map[(isbroadcast, f, args...)] = output

    return state
end

get_output(state::HardwareState, isbroadcast, f, args...) = state.output_map[(isbroadcast, f, args...)]

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

compress_name(name) =
    mapreduce(x -> startswith(x, ".") ? first(x, 2) : first(x, 1), *, split(replace(name, "net_" => ""), "_"))

function select_output_name!(ctx::HardwareCtx, f, args...; isbroadcast = false)
    f_name = isbroadcast ? "." * namify(f, ctx) : namify(f, ctx)
    arg_names = namify.(args, Ref(ctx))
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
        println("Popping $(namify(f, ctx))")
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

_materialize(ctx, x) = Cassette.tag(Base.Broadcast.materialize(Cassette.untag(x, ctx)), ctx, namify(x, ctx))

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
    arg_names = namify.(args, Ref(ctx))
    unwrapped_args = map(arg -> Cassette.untag(arg, ctx), args)
    element_args = map((arg, name) -> Cassette.tag(first(arg), ctx, name), unwrapped_args, arg_names)
    element_result = _overdub(ctx, f, element_args...; isbroadcast = true)
    result = Base.broadcasted(Cassette.untag(f, ctx), unwrapped_args...)

    return Cassette.tag(result, ctx, namify(element_result, ctx))
end

## Broadcasting primitives
#   don't recurse these calls

Cassette.prehook(ctx::HardwareCtx, ::typeof(Base.materialize), args...) = nothing
Cassette.posthook(ctx::HardwareCtx, output, ::typeof(Base.materialize), args...) = nothing
Cassette.overdub(ctx::HardwareCtx, ::typeof(Base.materialize), arg) =
    Cassette.tag(Cassette.fallback(ctx, Base.materialize, arg), ctx, namify(arg, ctx))

macro trace_primitive(f, args...)
    return quote
        # Cassette.overdub(ctx::HardwareCtx, ::typeof($(esc(f))), $(esc.(args)...)) =
        #     Cassette.fallback($(esc(f)), $(esc.(args)...))
        HW.istraceprimitive(::typeof($(esc(f))), $(esc.(args)...)) = true
    end
end

symbol_name(x) = QuoteNode(:($x))

function _generate(name, ex)
    if @capture(ex, f_(args__))
        tagged_args = map(arg -> Symbol(symbol_name(arg), :_tag), args)
        tagged_stmts = map((dest, arg) -> @q($dest = Cassette.tag($(esc(arg)), ctx, string($(symbol_name(arg))))),
                           tagged_args, args)

        @q begin
            ctx = Cassette.enabletagging(HardwareCtx(metadata = HardwareState()), $(esc(f)))
            $(tagged_stmts...)
            Cassette.@overdub ctx $(esc(f))($(tagged_args...))

            m = Module(name = $(symbol_name(name)))
            extracttrace!(m, ctx.metadata.current_trace)

            m
        end
    else
        error("@generate expects a function call (e.g. f(x, y))")
    end
end

macro generate(ex)
    return _generate(:top, ex)
end

macro generate(name, ex)
    return _generate(name, ex)
end