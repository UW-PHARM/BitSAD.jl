using Documenter, BitSAD

makedocs(;
    modules=[BitSAD],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
        "Introduction" => [
            "Getting started" => "getting-started.md",
            "Stochastic Bitstream Walkthrough" => "sbitstream-example.md",
            "Deterministic Bitstream Walkthrough" => "dbitstream-example.md",
        ],
        "Types" => [
            "Abstract Bitstreams" => "bitstream.md",
            "Stochastic Bitstreams" => "sbitstream.md",
            "Deterministic Bitstreams" => "dbitstream.md",
        ],
        "Hardware Generation" => [
            "Getting started" => "hardware-generation.md",
            "Internals" => "hardware-internals.md",
        ],
        "Customizing BitSAD" => [
            "Custom hardware generation" => "custom-hardware.md",
            "Custom `SBitstream` operators" => "custom-soperators.md",
        ],
    ],
    repo="https://github.com/UW-PHARM/BitSAD.jl/blob/{commit}{path}#L{line}",
    sitename="BitSAD.jl",
    authors="Kyle Daruwalla, University of Wisconsin-Madison PHARM Group",
    assets=String[],
)

deploydocs(;
    repo="github.com/UW-PHARM/BitSAD.jl",
)
