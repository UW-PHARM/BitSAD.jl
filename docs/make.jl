using Publish
using Artifacts, LazyArtifacts
using BitSAD

# override default theme
Publish.Themes.default() = artifact"flux-theme"

p = Publish.Project(BitSAD)

# needed to prevent error when overwriting
rm("dev", recursive = true, force = true)
rm(p.env["version"], recursive = true, force = true)

# build documentation
deploy(BitSAD; root = "/BitSAD.jl", force = true, label = "dev")
