module HW

using LightGraphs, MetaGraphs
using MacroTools
using MacroTools: @q
using Cassette
using Setfield
using LinearAlgebra

using ..BitSAD: SBitstream, SBitstreamLike

export AbstractHandler
export @circuit

include("netlist.jl")
include("handler.jl")
include("tracing.jl")
include("module.jl")
# include("circuit.jl")

end