using Base: @kwdef

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
@kwdef mutable struct Module
    name::Symbol
    parameters::Dict{Symbol, Number} = Dict{Symbol, Number}()
    submodules::Dict{Symbol, Symbol} = Dict{Symbol, Symbol}()
    dfg::MetaDiGraph{Int, Float64} = MetaDiGraph()
    handlers::Dict{Operation, AbstractHandler} = Dict{Operation, AbstractHandler}()
end

Base.show(io::IO, m::Module) =
    print(io, "Module $(m.name) with $(length(m.parameters)) parameters and $(length(m.submodules)) submodules.")
Base.show(io::IO, ::MIME"text/plain", m::Module) = print("""
    Module $(m.name):
        Parameters:
            $(m.parameters)
        Submodules:
            $(m.submodules)
        Number of operations: $(nv(m.dfg))
        Number of inputs: $(length(map(x -> getinputs(m.dfg, x), getroots(m.dfg))))
        Number of outputs: $(length(map(x -> getoutputs(m.dfg, x), getbuds(m.dfg))))
    """)

findnode(g::MetaDiGraph, inputs, outputs, operator) =
    collect(filter_vertices(g, (g, v) -> all(getname.(get_prop(g, v, :inputs)) .== inputs) &&
                                         all(getname.(get_prop(g, v, :outputs)) .== outputs) &&
                                         get_prop(g, v, :operator) == operator))
getroots(g::MetaDiGraph) = collect(filter_vertices(g, (g, v) -> isempty(inneighbors(g, v))))
getbuds(g::MetaDiGraph) = collect(filter_vertices(g, (g, v) -> isempty(outneighbors(g, v))))
getparents(g::MetaDiGraph, x::Variable) =
    filter_vertices(g, (g, v) -> x ∈ get_prop(g, v, :outputs))
getchildren(g::MetaDiGraph, x::Variable) =
    filter_vertices(g, (g, v) -> x ∈ get_prop(g, v, :inputs))
function traverse(g::MetaDiGraph, vs::Vector{T}, visited = T[]) where T
    levelup = unique(reduce(vcat, map(v -> outneighbors(g, v), vs)))
    parents = filter(v -> all(x -> x ∈ visited, inneighbors(g, v)), levelup)

    return parents, union(parents, visited)
end

function addnode!(m::Module, inputs::Vector{Variable}, outputs::Vector{Variable}, op::Symbol)
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

function updatetype!(m::Module, inputs::Vector{Variable}, outputs::Vector{Variable}, op::Symbol)
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

include("optimizations/constantreduction.jl")
include("optimizations/constantreplacement.jl")

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
function generate(m::Module, netlist::Netlist)
    outstr = ""
    m = deepcopy(m)

    printdfg(m)
    println()

    # run constant reduction
    constantreduction!(m, netlist)
    printdfg(m)
    println()
    constantreplacement!(m, netlist)
    printdfg(m)
    println()

    # start at inputs
    nodes = getroots(m.dfg)
    visited = nodes

    while !isempty(nodes)
        # for each node, invoke the appropriate handler
        for node in nodes
            inputs = getinputs(m.dfg, node)
            outputs = getoutputs(m.dfg, node)
            op = Operation(gettype.(inputs), gettype.(outputs), getoperator(m.dfg, node))

            if haskey(m.handlers, op)
                handler = m.handlers[op]
            else
                handler = gethandler(op)()
                m.handlers[op] = handler
            end

            outstr *= handler(netlist, inputs, outputs)
        end

        # move one level up in the DFG
        nodes, visited = traverse(m.dfg, nodes, visited)
    end

    return outstr
end
function generate(m::Module, f)
    # get runtime info and populate netlist
    netlist = Netlist()
    f(netlist)

    return generate(m, netlist)
end
generate(c::Tuple{Module, Function}, dut, args...) = generate(c[1], (netlist) -> c[2](dut, c[1], netlist, args...))