module BitSAD

using DataStructures
using UUIDs, PearsonHash
using Random: MersenneTwister
using Setfield
using MacroTools
using Cassette
using Reexport

export AbstractBitstream
export SBit, SBitstream
export DBit, DBitstream
export pos, neg, float
export zero, one
export +, -, *, /, ÷, sqrt, decorrelate, norm
export generate, generate!, estimate!
export push!, pop!, observe, length
# export SDM
export @simulate

include("types/bitstream.jl")
include("types/sbitstream.jl")
include("idutils.jl")
# include("types/dbitstream.jl")
# include("modules/sdm.jl")

include("hardware/HW.jl")

@reexport using .HW

end # module
