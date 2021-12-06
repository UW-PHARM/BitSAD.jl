const Operation = @NamedTuple{name::Symbol, type::DataType, broadcasted::Bool}

_nameof(x) = nameof(typeof(x))
_nameof(x::Function) = nameof(x)

"""
    Module

A data structure to store information to generate hardware for a circuit.
This structure can be manually modified if needed but typically [`@circuit`](@ref)
is used to auto-populate it.

Hardware generation traverses `dfg` and uses `handlers` to generate Verilog strings.

# Fields:
- `name::Symbol`: the name of the module
- `parameters::Dict{Symbol, Number}`: a map from the name of each parameter to its default value
- `submodules::Vector{Type}`: a list of submodule types
- `dfg::MetaDiGraph{Int, Float64}`: a data flow graph representing the circuit to be generated
- `handlers::Dict{Operation, AbstractHandler}`: a map from operation type to a hardware generation handler.

See also: [HW.generate](@ref)
"""
@kwdef mutable struct Module{T}
    fn::T
    name::Symbol = _nameof(fn)
    bitwidth::@NamedTuple{integral::Int, fractional::Int} = (integral = 1, fractional = 0)
    parameters::Dict{String, Any} = Dict{String, Any}()
    submodules::Vector{Type} = Type[]
    dfg::MetaDiGraph{Int, Float64} = MetaDiGraph()
    handlers::Dict{Any, Tuple{Any, Any}} = Dict{Any, Tuple{Any, Any}}()
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

getinputs(g::MetaDiGraph, v) = get_prop(g, v, :inputs)
getoutputs(g::MetaDiGraph, v) = get_prop(g, v, :outputs)
getoperator(g::MetaDiGraph, v) = get_prop(g, v, :operator)

findnode(g::MetaDiGraph, inputs, outputs, operator) =
    collect(filter_vertices(g, (g, v) -> all(getname.(getinputs(g, v)) .== inputs) &&
                                         all(getname.(getoutputs(g, v)) .== outputs) &&
                                         get_prop(g, v, :operator) == operator))
getroots(g::MetaDiGraph) = collect(filter_vertices(g, (g, v) -> isempty(inneighbors(g, v))))
getbuds(g::MetaDiGraph) = collect(filter_vertices(g, (g, v) -> isempty(outneighbors(g, v))))
getparents(g::MetaDiGraph, x::Net) =
    filter_vertices(g, (g, v) -> x ∈ getoutputs(g, v))
getchildren(g::MetaDiGraph, x::Net) =
    filter_vertices(g, (g, v) -> x ∈ getinputs(g, v))
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

function getnetlist(m::Module)
    netlist = Net[]
    for v in vertices(m.dfg)
        inputs = getinputs(m.dfg, v)
        outputs = getoutputs(m.dfg, v)
        append!(netlist, inputs)
        append!(netlist, outputs)
    end

    return netlist |> unique
end

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
            println("")
        end

        nodes, visited = traverse(m.dfg, nodes, visited)
        padding *= "   "
    end
end

function _printnet(net::Net)
    reg = isreg(net) ? "reg" : ""
    bitlength = bitwidth(net) * prod(netsize(net)) - 1
    bitstr = (bitlength == 0) ? "" : "[$bitlength:0]"
    names = issigned(net) ? "$(name(net))_p, $(name(net))_m" : name(net)

    return join([reg, bitstr, names], " ")
end

_encodeparameter(buffer, name, value) =
    write(buffer, "parameter $name = $value;")
function _encodeparameter(buffer, name, value::AbstractArray)
    for (i, sz) in enumerate(size(value))
        write(buffer, "parameter $(name)_sz_$i = $sz;\n")
    end
    write(buffer, "parameter $name = {")
    write(buffer, join(value, ", "))
    write(buffer, "};")
end
function _encodeparameter(buffer, name, value::Tuple)
    write(buffer, "parameter $(name)_sz_1 = $(length(value));\n")
    write(buffer, "parameter $name = {")
    write(buffer, join(value, ", "))
    write(buffer, "};")
end

function _generatetopmatter(buffer, m::Module, netlist::Netlist)
    netlist = unique(netlist)
    inputs = filter(isinput, netlist)
    outputs = filter(isoutput, netlist)
    # parameters = filter(isparameter, netlist)
    internals = filter(isinternal, netlist)
    wires = filter(iswire, internals)
    regs = filter(isreg, internals)

    write(buffer, "module $(m.name)(CLK, nRST, ")

    write(buffer, join(map(inputs) do input
        issigned(input) ? "$(name(input))_p, $(name(input))_m" : name(input)
    end, ", "))
    write(buffer, ", ")
    write(buffer, join(map(outputs) do output
        issigned(output) ? "$(name(output))_p, $(name(output))_m" : name(output)
    end, ", "))
    write(buffer, ");\n")

    for (name, value) in m.parameters
        _encodeparameter(buffer, name, value)
        write(buffer, "\n")
    end
    write(buffer, "\n")

    write(buffer, "input ClK, nRST;\n")

    write(buffer, join(map(inputs) do input
        "input $(_printnet(input));"
    end, "\n"))
    write(buffer, "\n")
    write(buffer, join(map(outputs) do output
        "output $(_printnet(output));"
    end, "\n"))
    write(buffer, "\n")
    write(buffer, join(map(_printnet, regs), "\n"))
    write(buffer, "\n")
    write(buffer, join(map(wires) do wire
        "wire $(_printnet(wire));"
    end, "\n"))
    write(buffer, "\n\n")

    return buffer
end

function _sync_nodes!(nets, netlist)
    for (i, net) in enumerate(nets)
        j = find(netlist, net)
        if !isempty(j)
            nets[i] = only(netlist[j])
        end
    end

    return nets
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
function generateverilog(io::IO, m::Module)
    outstr = ""
    netlist = getnetlist(m)

    # start at inputs
    nodes = getroots(m.dfg)
    visited = nodes

    buffer = (io isa IOBuffer) ? IOBuffer() : mktemp()[2]
    while !isempty(nodes)
        # for each node, invoke the appropriate handler
        for node in nodes
            inputs = getinputs(m.dfg, node)
            outputs = getoutputs(m.dfg, node)
            operator = getoperator(m.dfg, node)

            handler = gethandler(operator.broadcasted, operator.type, jltypeof.(inputs)...)
            handler, state = get!(m.handlers, typeof(handler), (handler, init_state(handler)))

            set_prop!(m.dfg, node, :inputs, _sync_nodes!(inputs, netlist))
            _, state = handler(buffer, netlist, state, inputs, outputs)
            m.handlers[typeof(handler)] = (handler, state)
            set_prop!(m.dfg, node, :outputs, _sync_nodes!(outputs, netlist))
        end

        # move one level up in the DFG
        nodes, visited = traverse(m.dfg, nodes, visited)
    end

    # set outputs
    for v in getbuds(m.dfg)
        for output in getoutputs(m.dfg, v)
            setclass!(netlist, output, :output)
        end
    end

    # print top matter
    _generatetopmatter(io, m, netlist)
    # print main matter
    seekstart(buffer)
    for line in eachline(buffer)
        write(io, line)
        write(io, "\n")
    end
    write(io, "\nendmodule\n")

    return io
end
generateverilog(m::Module) = generateverilog(IOBuffer(), m)
