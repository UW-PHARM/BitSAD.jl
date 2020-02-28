# BitSAD.jl

BitSAD is a domain-specific language for bitstream computing. It aims to provide a general purpose linear algebra interface for writing algorithms that can be mapped to bitstream computing hardware. Programs written in BitSAD can be turned into synthesizable, verified Verilog code.

See [CITATION.bib](https://github.com/UW-PHARM/BitSAD.jl/blob/master/CITATION.bib) for how to cite BitSAD if you use it in your research.

_**Note:** Hardware generation is still being ported over to BitSAD.jl from the original Scala implementation._

```@contents
```

## Installation

You can install BitSAD by opening a Julia REPL and entering:

```
> ] add https://github.com/UW-PHARM/BitSAD.jl
```