# BitSAD

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://UW-PHARM.github.io/BitSAD.jl/dev)
[![CI](https://github.com/UW-PHARM/BitSAD.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/UW-PHARM/BitSAD.jl/actions/workflows/CI.yml)

BitSAD is a domain-specific framework for bitstream computing. It aims to provide a general purpose linear algebra interface for writing algorithms that can be mapped to bitstream computing hardware. Programs written in BitSAD can be turned into synthesizable, verified SystemVerilog code.

See [CITATION.bib](https://github.com/UW-PHARM/BitSAD.jl/blob/master/CITATION.bib) for how to cite BitSAD if you use it in your research.

_**Note:** Deterministic bitstreams are temporarily unavailable._

## Installation

You can install BitSAD by opening a Julia REPL and entering (note that the `]` indicates [Pkg mode](https://docs.julialang.org/en/v1.6/stdlib/REPL/#Pkg-mode)):

```
] add BitSAD
```
