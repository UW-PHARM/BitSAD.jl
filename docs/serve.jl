using Publish
using BitSAD
using Artifacts, LazyArtifacts

# override default theme
Publish.Themes.default() = artifact"flux-theme"

p = Publish.Project(BitSAD)

# serve documentation
serve(BitSAD)
