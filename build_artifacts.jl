using Pkg.Artifacts
using Pkg.TOML

# This is the path to the Artifacts.toml we will manipulate
artifact_toml = joinpath(@__DIR__, "Artifacts.toml")
verilog_lib = joinpath(@__DIR__, "verilog-stdlib/")
project_toml = TOML.parsefile(joinpath(@__DIR__, "Project.toml"))
version = project_toml["version"]

# create_artifact() returns the content-hash of the artifact directory once we're finished creating it
dir_hash = create_artifact() do artifact_dir
    # We create the artifact by simply copying over the library
    cp(verilog_lib, artifact_dir; force = true)
end
# compress the artifact dir into a tar archive
tar_hash = archive_artifact(dir_hash, joinpath(@__DIR__, "verilog-stdlib.tar.gz"))

# Now bind that hash within our `Artifacts.toml`
base_url = "https://github.com/UW-PHARM/BitSAD.jl/raw"
dev_url = "$base_url/master/verilog-stdlib.tar.gz"
release_url = "$base_url/v$version/verilog-stdlib.tar.gz"
bind_artifact!(artifact_toml, "verilog-stdlib", dir_hash;
               download_info = [(release_url, tar_hash), (dev_url, tar_hash)],
               force = true,
               lazy = true)
