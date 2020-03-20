# Generating hardware

Consider the circuit defined in [Walking through an `SBitstream` Example](@ref) shown below.

```julia
using BitSAD

circuit = @circuit IterativeSVD begin
    parameters : [
        rows::Int => 2,
        cols::Int => 2
    ]

    circuit : (dut::IterativeSVD)(A::Matrix{SBit}, v₀::Vector{SBit}) -> begin
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
end

dut = IterativeSVD(2, 2)
A = SBitstream(rand(2, 2))
v₀ = SBitstream(rand(2, 1))
```

The `circuit` defined above as the return of `@circuit` is a `Tuple{HW.Module, Function}`. A [`HW.Module`](@ref) is a type provided by BitSAD to store all hardware generation information. It contains several dictionaries storing the parameter and submodule information, as well as a data-flow graph object that represents the body of the module's execution. The function returned in the tuple is an auto-generated function that extracts runtime information and stores it in the `Module` object.

In general, you don't need to worry about these pieces. You can simply use the [`HW.generate`](@ref) function directly on the tuple. To do this, you will need three pieces -- the tuple returned by `@circuit`, an instance of your module (e.g. `dut` above), and example arguments to the implementation (e.g. `A` and `v₀` above).

```julia
println(HW.generate(circuit, dut, A, v₀))
```

That is all that is needed to generate the hardware. See [Hardware internals](@ref) for more details on how this happens.