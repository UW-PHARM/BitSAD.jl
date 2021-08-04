module BitSAD

using DataStructures
using UUIDs, PearsonHash
using Random: MersenneTwister
using Setfield
using MacroTools
using Ghost
using Reexport

export AbstractBitstream
export SBit, SBitstream
export DBit, DBitstream
export pos, neg, float
export zero, one
export +, -, *, /, ÷, sqrt, decorrelate, norm
export generate, generate!, estimate, estimate!
export push!, pop!, observe, length
# export SDM
# export @simulate

include("tracing/trace.jl")

include("types/bitstream.jl")
include("types/sbitstream.jl")
include("idutils.jl")
# include("types/dbitstream.jl")
# include("modules/sdm.jl")

# include("tracing/netlist.jl")
# include("tracing/circuit.jl")
include("tracing/simulatable.jl")

# include("hardware/HW.jl")

# @reexport using .HW

end # module
