module BitSAD

using DataStructures
using UUIDs, PearsonHash
using Random: MersenneTwister
using MacroTools

export AbstractBit, AbstractBitstream
export SBit, SBitstream
export pos, neg
export +, -, *, /, ÷, sqrt, decorrelate, norm
export generate, generate!
export push!, pop!, observe

include("types/bitstream.jl")
include("types/sbitstream.jl")

end # module
