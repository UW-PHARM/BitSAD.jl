using Pkg

Pkg.develop(path = "..")

using Publish
using Artifacts, LazyArtifacts
using BitSAD

# override default theme
cp(artifact"flux-theme", "../_flux-theme"; force = true)

p = Publish.Project(BitSAD)

function build_and_deploy(label)
    rm(label; recursive = true, force = true)
    deploy(BitSAD; root = "/BitSAD.jl", label = label)
end
