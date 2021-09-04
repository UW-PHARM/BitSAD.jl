module BitSAD

using LinearAlgebra
using DataStructures
using Random: MersenneTwister
using Setfield
using Ghost
using LightGraphs, MetaGraphs
using Base: @kwdef

export AbstractBitstream
export SBit, SBitstream
# export DBit, DBitstream
export pos, neg
export decorrelate
export generate, generate!, estimate, estimate!, observe
# export SDM
export simulatable
export generatehw

include("tracing/trace.jl")

include("types/bitstream.jl")
include("types/sbitstream.jl")
# include("types/dbitstream.jl")
# include("modules/sdm.jl")

include("tracing/utilities.jl")
include("tracing/simulatable.jl")
include("tracing/netlist.jl")
include("tracing/circuit.jl")
include("tracing/transforms/constantreplacement.jl")
include("tracing/transforms/constantreduction.jl")
include("tracing/hardware.jl")

include("hardware/utils.jl") 
include("hardware/saddhandler.jl")
include("hardware/ssubhandler.jl")
include("hardware/smulthandler.jl")
include("hardware/sdivhandler.jl")
include("hardware/sfdivhandler.jl")
include("hardware/ssqrthandler.jl")
include("hardware/sl2normhandler.jl")
include("hardware/transposehandler.jl")
# include("hardware/daddhandler.jl")
# include("hardware/dsubhandler.jl")
# include("hardware/dmulthandler.jl")
# include("hardware/fxpaddhandler.jl")
# include("hardware/fxpsubhandler.jl")
# include("hardware/fxpmulthandler.jl")
# include("hardware/sdmhandler.jl")
# include("hardware/delaybufferhandler.jl")

end # module
