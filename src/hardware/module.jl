using Base: @kwdef

@kwdef mutable struct Module
    name::Symbol
    parameters::Dict{Symbol, Number} = Dict{Symbol, Number}()
    dfg::MetaDiGraph{Int, Float64} = MetaDiGraph()
end

Base.show(io::IO, m::Module) = print(io, "Module $(m.name) with $(length(m.parameters)) parameters")
Base.show(io::IO, ::MIME"text/plain", m::Module) = print("""
    Module $(m.name):
        Parameters:
            $(m.parameters)
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
traverse(g::MetaDiGraph, vs) = unique(reduce(vcat, map(v -> outneighbors(g, v), vs)))

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

function asksize(x::String)
    print("What is the size of $x (as a tuple)? ")
    resp = match(r"\((\d+),\s*(\d+)\)", readline())

    if length(resp.captures) != 2 || any(isnothing, resp.captures)
        error("Cannot understand response. Enter a tuple (i.e. (row, col))")
    end

    row = parse(Int, resp.captures[1])
    col = parse(Int, resp.captures[2])

    return (row, col)
end

function generate(m::Module)
    netlist = Netlist()
    handlers = Dict{Operation, AbstractHandler}()
    outstr = ""

    # start at inputs
    nodes = getroots(m.dfg)

    # add inputs to netlist
    for node in nodes
        inputs = getinputs(m.dfg, node)
        for input in inputs
            if !contains(netlist, getname(input))
                s = asksize(getname(input))
                update!(netlist, Net(name = getname(input), class = :input, signed = true, size = s))
            end
        end
    end

    while !isempty(nodes)
        # for each node, invoke the appropriate handler
        for node in nodes
            inputs = getinputs(m.dfg, node)
            outputs = getoutputs(m.dfg, node)
            op = Operation(gettype.(inputs), gettype.(outputs), getoperator(m.dfg, node))

            if haskey(handlers, op)
                handler = handlers[op]
            else
                handler = gethandler(op)()
                handlers[op] = handler
            end

            outstr *= handler(netlist, inputs, outputs, getsize(netlist, getname.(inputs)))
        end

        # move one level up in the DFG
        nodes = traverse(m.dfg, nodes)
    end

    return outstr
end
function generate(m::Module, f)
    # get types
    f()

    return generate(m)
end
generate(c::Tuple{Module, Function}, dut, args...) = generate(c[1], () -> c[2](dut, c[1], args...))