using Base: @kwdef

struct Variable
    name::Symbol
    type::Symbol
end

@kwdef struct Module
    name::Symbol
    parameters::Dict{Symbol, Number} = Dict{Symbol, Number}()
    dfg::MetaDiGraph{Int, Float64} = MetaDiGraph()
end

getparents(g::MetaDiGraph, x::Variable) =
    filter_vertices(g, (g, v) -> x ∈ get_prop(g, v, :outputs))
getchildren(g::MetaDiGraph, x::Variable) =
    filter_vertices(g, (g, v) -> x ∈ get_prop(g, v, :inputs))

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