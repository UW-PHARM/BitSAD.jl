# Create a simulation nop

A "nop" (or "no op") is an operation that passes its inputs through unmodified. A _simulation nop_ is a function that is not traced by the BitSAD simulator. Instead, that call stack is "passed through" unmodified. Let's look at a concrete example.

{cell=nop}
```julia
using BitSAD
using LinearAlgebra

f(x) = reverse(x)
g(v) = norm(v)
h(x) = g(f(x))

v = SBitstream.(rand(3) ./ 10)
h(v)
```

If we look at the transformed simulation code for `h`, we see that BitSAD recurses into the call stack of `f`.

{cell=nop}
```julia
BitSAD.show_simulatable(h, v)
```

Suppose instead of unwrapping the call to `f`, we want the simulator to call `f` itself on the plain arguments. We can do this with [`BitSAD.@nosim`](#).

{cell=nop}
```julia
BitSAD.@nosim f(x)
```

By declaring `f(x)` as a simulation nop, we prevent BitSAD from tracing into _any_ call matching `f(::Any)`. Instead, BitSAD will call `f(x)`.

!!! tip
    You can use type signatures to restrict which methods of a function are marked as simulation nops. For example, `f(x::SBitstream)` will only prevent tracing into `f` when `typeof(x) <: SBitstream`. When no type signature is given, the argument type defaults to `Any`.

{cell=nop}
```julia
BitSAD.show_simulatable(h, v)
```

!!! warning
    Notice that `f` is called on `x2` directly (i.e. there is no call to `getbit`). Marking a call as a simulation nop bypasses the `getbit`/`setbit!` calls inserted by the simulator for _all_ arguments.
