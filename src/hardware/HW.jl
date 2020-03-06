module HW

using LightGraphs, MetaGraphs

export AbstractHandler

include("netlist.jl")
include("handler.jl")
include("module.jl")

end