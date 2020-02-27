module BitSAD

using DataStructures
using UUIDs, PearsonHash
using Random: MersenneTwister
using MacroTools

export AbstractBit, AbstractBitstream
export SBit, SBitstream
export DBit, DBitstream
export float, pos, neg
export zero, one
export +, -, *, /, ÷, sqrt, decorrelate, norm
export generate, generate!, estimate!
export push!, pop!, observe, length
export SDM

include("types/bitstream.jl")
include("types/sbitstream.jl")
include("types/dbitstream.jl")
include("modules/sdm.jl")

end # module
