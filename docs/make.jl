using Documenter, BitSAD

makedocs(;
    modules=[BitSAD],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
    ],
    repo="https://github.com/UW-PHARM/BitSAD.jl/blob/{commit}{path}#L{line}",
    sitename="BitSAD.jl",
    authors="Kyle Daruwalla, University of Wisconsin-Madison PHARM Group",
    assets=String[],
)

deploydocs(;
    repo="github.com/UW-PHARM/BitSAD.jl",
)
