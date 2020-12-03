using Base: @kwdef

const Operation = @NamedTuple{name::Symbol, type::DataType, broadcasted::Bool}

"""
    Module

A data structure to store information to generate hardware for a circuit.
This structure can be manually modified if needed but typically [`@circuit`](@ref)
is used to auto-populate it.

Hardware generation traverses `dfg` and uses `handlers` to generate Verilog strings.

# Fields:
- `name::Symbol`: the name of the module
- `parameters::Dict{Symbol, Number}`: a map from the name of each parameter to its default value
- `submodules::Dict{Symbol, Symbol}`: a map from the name of each submodule to its type
- `dfg::MetaDiGraph{Int, Float64}`: a data flow graph representing the circuit to be generated
- `handlers::Dict{Operation, AbstractHandler}`: a map from operation type to a hardware generation handler.

See also: [HW.generate](@ref)
"""
@kwdef struct Module
    name::Symbol
    parameters::Dict{Symbol, Number} = Dict{Symbol, Number}()
    submodules::Dict{Symbol, Symbol} = Dict{Symbol, Symbol}()
    dfg::MetaDiGraph{Int, Float64} = MetaDiGraph()
    handlers::Dict{Tuple{Bool, Vararg{Type}}, AbstractHandler} = Dict{Tuple{Bool, Vararg{Type}}, AbstractHandler}()
end

Base.show(io::IO, m::Module) =
    print(io, "Module $(m.name) with $(length(m.parameters)) parameters and $(length(m.submodules)) submodules.")
Base.show(io::IO, ::MIME"text/plain", m::Module) = print(io, """
    Module $(m.name):
        Parameters:
            $(m.parameters)
        Submodules:
            $(m.submodules)
        Number of operations: $(nv(m.dfg))
        Number of inputs: $(length(map(x -> getinputs(m.dfg, x), getroots(m.dfg))))
        Number of outputs: $(length(map(x -> getoutputs(m.dfg, x), getbuds(m.dfg))))
    """)

function printdfg(m::Module)
    nodes = getroots(m.dfg)
    visited = nodes
    padding = ""

    while !isempty(nodes)
        for node in nodes
            inputs = getinputs(m.dfg, node)
            outputs = getoutputs(m.dfg, node)
            op = getoperator(m.dfg, node)
            println("$(padding)inputs: $inputs")
            println("$(padding)outputs: $outputs")
            println("$(padding)op: $op")
        end

        nodes, visited = traverse(m.dfg, nodes, visited)
        padding *= "   "
    end
end

findnode(g::MetaDiGraph, inputs, outputs, operator) =
    collect(filter_vertices(g, (g, v) -> all(getname.(get_prop(g, v, :inputs)) .== inputs) &&
                                         all(getname.(get_prop(g, v, :outputs)) .== outputs) &&
                                         get_prop(g, v, :operator) == operator))
getroots(g::MetaDiGraph) = collect(filter_vertices(g, (g, v) -> isempty(inneighbors(g, v))))
getbuds(g::MetaDiGraph) = collect(filter_vertices(g, (g, v) -> isempty(outneighbors(g, v))))
getparents(g::MetaDiGraph, x::Net) =
    filter_vertices(g, (g, v) -> x ∈ get_prop(g, v, :outputs))
getchildren(g::MetaDiGraph, x::Net) =
    filter_vertices(g, (g, v) -> x ∈ get_prop(g, v, :inputs))
function traverse(g::MetaDiGraph, vs::Vector{T}, visited = T[]) where T
    levelup = unique(reduce(vcat, map(v -> outneighbors(g, v), vs)))
    parents = filter(v -> all(x -> x ∈ visited, inneighbors(g, v)), levelup)

    return parents, union(parents, visited)
end

function addnode!(m::Module, inputs::Vector{Net}, outputs::Vector{Net}, op::Operation)
    add_vertex!(m.dfg)
    node = nv(m.dfg)
    set_prop!(m.dfg, node, :inputs, inputs)
    set_prop!(m.dfg, node, :outputs, outputs)
    set_prop!(m.dfg, node, :operator, op)

    for input in inputs
        for parent in getparents(m.dfg, input)
            add_edge!(m.dfg, parent, node)
        end
    end

    for output in outputs
        for child in getchildren(m.dfg, output)
            add_edge!(m.dfg, node, child)
        end
    end

    return m
end

function updatetype!(m::Module, inputs::Vector{Net}, outputs::Vector{Net}, op::Operation)
    innames = getname.(inputs)
    outnames = getname.(outputs)
    v = findnode(m.dfg, innames, outnames, op)
    isempty(v) && error("""
        Could not update node because it was not found in DFG.
        inputs: $innames
        outputs: $outnames
        operator: $op
        """)
    set_prop!(m.dfg, v[1], :inputs, inputs)
    set_prop!(m.dfg, v[1], :outputs, outputs)
    set_prop!(m.dfg, v[1], :operator, op)

    return m
end

getinputs(g::MetaDiGraph, v) = get_prop(g, v, :inputs)
getoutputs(g::MetaDiGraph, v) = get_prop(g, v, :outputs)
getoperator(g::MetaDiGraph, v) = get_prop(g, v, :operator)

function extracttrace!(m::Module, trace::Trace)
    _checkconstant(x) = x
    _checkconstant(x::Real) = (@set! x.class = :constant)

    for call in trace
        if hassubtrace(call)
            extracttrace!(m, call.subtrace)
        else
            # check for constants
            map(_checkconstant, call.inputs)

            op = (name = call.operator, type = call.optype, broadcasted = call.broadcasted)
            addnode!(m, call.inputs, call.outputs, op)
        end
    end

    return m
end

# include("optimizations/constantreduction.jl")
# include("optimizations/constantreplacement.jl")

"""
    HW.generate(m::Module, netlist::Netlist)
    HW.generate(m::Module, f)
    HW.generate(c::Tuple{Module, Function}, dut, args...)

Generate the Verilog implementation of the module.
Users will most likely call the last method form above.

# Fields:
- `m::Module`: the module to generate
- `netlist::Netlist`: the netlist for the circuit being generated
- `f`: a closure with one argument (a netlist) that calls a runtime information extraction function
- `c::Tuple{Module, Function}`: the tuple returned by [`@circuit`](@ref)
- `dut`: an instance of the circuit struct
- `args`: example arguments to circuit
"""
function generate(m::Module)
    outstr = ""
    netlist = Net[]
    # m = deepcopy(m)

    # printdfg(m)
    # println()

    # run constant reduction
    # constantreduction!(m, netlist)
    # printdfg(m)
    # println()
    # constantreplacement!(m, netlist)
    # printdfg(m)
    # println()

    # start at inputs
    nodes = getroots(m.dfg)
    visited = nodes

    while !isempty(nodes)
        # for each node, invoke the appropriate handler
        for node in nodes
            inputs = getinputs(m.dfg, node)
            outputs = getoutputs(m.dfg, node)
            operator = getoperator(m.dfg, node)
            op = (operator.broadcasted, operator.type, jltype.(inputs)...)

            # check if input is already in netlist
            # if not assume it is an input to full DFG
            for input in inputs
                (input ∈ netlist) && @set! input.class = :input
            end

            # add "edges" to netlist
            append!(netlist, inputs)
            append!(netlist, outputs)

            if haskey(m.handlers, op)
                handler = m.handlers[op]
            else
                handler = gethandler(op...)
                m.handlers[op] = handler
            end

            outstr *= handler(netlist, inputs, outputs)
        end

        # move one level up in the DFG
        nodes, visited = traverse(m.dfg, nodes, visited)
    end

    return outstr
end

## Utilities for translating a call to a Module by tracing

symbol_name(x) = QuoteNode(:($x))

function _trace_module(name, ex)
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

            m, ctx.metadata.current_trace
        end
    else
        error("@generate expects a function call (e.g. f(x, y))")
    end
end

macro trace(ex)
    return _trace_module(:top, ex)
end

macro trace(name, ex)
    return _trace_module(name, ex)
end