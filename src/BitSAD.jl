module BitSAD

using LinearAlgebra
using DataStructures
using Random
using RandomNumbers
using Setfield
using Ghost
using OrderedCollections: LittleDict
using MacroTools: @capture
using LightGraphs, MetaGraphs
using Base: @kwdef
using Artifacts, LazyArtifacts

export SBit, SBitstream
# export DBit, DBitstream
export pos, neg
export decorrelate
export generate, generate!, estimate, estimate!, observe
# export SDM
export simulatable
export generatehw

const verbosity = Base.RefValue(:full)
function set_saturation_verbosity(level = :full)
    level ∈ (:full, :none) ||
        throw(ArgumentError("Verbosity level can be one of (:full or :none) (got $level)"))
    verbosity[] = level

    return nothing
end

include("tracing/trace.jl")

include("types/sbitstream.jl")
# include("types/dbitstream.jl")
# include("modules/sdm.jl")

include("tracing/utilities.jl")
include("tracing/simulatable.jl")
include("tracing/netlist.jl")
include("tracing/circuit.jl")
include("tracing/transforms/insertrng.jl")
include("tracing/transforms/constantreplacement.jl")
include("tracing/transforms/constantreduction.jl")
include("tracing/hardware.jl")

include("hwhandlers/utils.jl")
include("hwhandlers/sbitstream/sbitstreamhandler.jl")
include("hwhandlers/sbitstream/saddhandler.jl")
include("hwhandlers/sbitstream/ssubhandler.jl")
include("hwhandlers/sbitstream/smulthandler.jl")
include("hwhandlers/sbitstream/sdivhandler.jl")
include("hwhandlers/sbitstream/sfdivhandler.jl")
include("hwhandlers/sbitstream/ssqrthandler.jl")
include("hwhandlers/sbitstream/sl2normhandler.jl")
include("hwhandlers/sbitstream/smaxhandler.jl")
include("hwhandlers/transposehandler.jl")
include("hwhandlers/reshapehandler.jl")
include("hwhandlers/identityhandler.jl")
# include("hardware/daddhandler.jl")
# include("hardware/dsubhandler.jl")
# include("hardware/dmulthandler.jl")
# include("hardware/fxpaddhandler.jl")
# include("hardware/fxpsubhandler.jl")
# include("hardware/fxpmulthandler.jl")
# include("hardware/sdmhandler.jl")
# include("hardware/delaybufferhandler.jl")

function download_lib(dir = pwd())
    lib = artifact"verilog-stdlib"
    cp(lib, joinpath(dir, "verilog-stdlib"))
end

end # module
