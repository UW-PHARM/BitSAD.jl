using Pkg

Pkg.develop(path = "..")

using Publish
using BitSAD
using Artifacts, LazyArtifacts

# override default theme
cp(artifact"flux-theme", "../_flux-theme"; force = true)

p = Publish.Project(BitSAD)

# serve documentation
serve(BitSAD)
