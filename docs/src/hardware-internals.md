# Hardware internals

From the user perspective, generating hardware seems fairly trivial. Yet, there is a lot happening under the hood to make this possible. It will be important to understand these details if you want to customize the hardware generation process.

All the information for hardware generation is stored in a `Module` object. The `HW.generate` function operates on this object to output a Verilog string. Users will typically use `@circuit` to generate the module object.

```@docs
HW.Module
HW.generate
@circuit
```

# `@circuit` internals

The `@circuit` is responsible for parsing a domain-specific language for creating and populating `Module` objects. In [Generating hardware](@ref), we see an example of `@circuit` being used. Here is an equivalent piece of code for achieving the same goal without using `@circuit`

```julia
using BitSAD
using BitSAD.HW: Variable

Base.@kwdef struct IterativeSVD
    rows::Int = 2
    cols::Int = 2
end

function (dut::IterativeSVD)(A::Matrix{SBit}, v₀::Vector{SBit})
    # Update right singular vector
    w = A * v₀
    wscaled = w .÷ sqrt(dut.rows)
    u = wscaled ./ norm(wscaled)

    # Update left singular vector
    z = permutedims(A) * u
    zscaled = z .÷ sqrt(dut.cols)
    σ = norm(zscaled)
    v = zscaled ./ σ

    return u, v, σ
end

# manually create Module
m = Module(name = Symbol("IterativeSVD"))

# manually populate module DFG
inputs = [Variable(:A, :Any), Variable(:v₀, :Any)]
outputs = [Variable(:w, :Any)]
op = :*
addnode!(m, inputs, outputs)
# ... remaining addnode! calls left out for brevity

# define runtime info extraction function
function extractrtinfo!(dut::IterativeSVD, m::BitSAD.HW.Module, netlist::BitSAD.HW.Netlist, A::Matrix{SBit}, v₀::Vector{SBit})
    w = extractrtinfo!(m, netlist, [:A, :v₀], :w, *, false, nothing, A, v₀)
    wscaled = extractrtinfo!(m, netlist, [:w, :net_2_2_1], :wscaled, div, true, nothing, w,
                    extractrtinfo!(m, netlist, [:rows], :net_2_2_1, sqrt, false, nothing, dut.rows)
                )
    # ... remaining lines ommitted for brevity
end

circuit = (m, extractrtinfo!)
```

We ommitted several lines to keep the snippet above short, but as you can see, for each operation in the DFG, there are many auto-generated lines of code.

# `HW.generate` internals

The `HW.generate` goes through several stages to produce the output Verilog string. Here are those steps (assuming `circuit` is the tuple returned by `@circuit`):

1. Call `HW.generate(circuit, dut, args...)` where `dut` refers to an instance of the algorithm struct and `args...` are the example arguments to the circuit.
2. This function in turn calls `HW.generate(circuit[1], (netlist) -> circuit[2](dut, circuit[1], netlist, args...))`.
3. This function in turn does:
    1. Creates a new netlist with `netlist = Netlist()`.
    2. Populates the module and netlist with runtime information calling `f(netlist)` where `f` is the anonymous function in Step 2 above.
    3. Calls `HW.generate(module, netlist)` where `module` is `circuit[1]` populated with runtime info using `f`.
4. We now step through the main hardware generation function:
    1. Apply the constant reduction phase to reduce expressions containing only compile time literals or module parameters.
    2. Apply the constant replacement phase to transform each constant in the circuit into a binary Verilog literal.
    3. Traverse the DFG from inputs to outputs in breadth-first fashion. For each node in the traversal:
        1. Get the current handler object corresponding to the operation and input/output types of the node.
        2. Call the handler object passing the current node's inputs/outputs and netlist. The handler will update the netlist if necessary and return a Verilog string instantiating that operation into the total circuit.
    4. Return all the Verilog strings concatenated together.

`HW.generate` makes a deep-copy of the `Module` object, so any optimization phases above do not modify the DFG generated by `@circuit`. This allows you to call `HW.generate` multiple times with different example arguments. This can be useful if you want to programmatically generate many versions of the same circuit with different parameters (e.g. different matrix sizes).