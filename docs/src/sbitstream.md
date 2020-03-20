# Stochastic Bitstreams

An `SBitstream` is a stochastic bitstream representing a sequence of `SBit`s. Each `SBitstream` is associated with an underlying real value.

```@docs
SBit
SBitstream
```

To represent signed numbers in ``[-1, 1]``, we use two single bitstreams — a positive channel and a negative channel. So, an `SBit` is actually a tuple of two boolean values.

```@docs
pos
neg
```

We can also access the underlying real value using `float`.

```@docs
float(b::SBit)
```

Finally, we can fill up a `SBitstream` with a bit sequence using `generate!` and estimate the empirical average using `estimate!`.

```@docs
generate
estimate!
```

# Operators

The following operations are defined for `SBit`s and `SBitstream`s.

| Operation               | Name                | Conditions |
| :---------------------- | :------------------ | :--------- |
| `+(x::SBit, y::SBit)`   | Addition            | None       |
| `-(x::SBit, y::SBit)`   | Subtraction         | None       |
| `*(x::SBit, y::SBit)`   | Multiplication      | None       |
| `/(x::SBit, y::SBit)`   | Division            | `y > 0`    |
| `÷(x::SBit, y::Real)`   | Fixed-Gain Division | `y >= 1`   |
| `sqrt(x::SBit)`         | Square Root         | `x >= 0`   |
| `norm(x::Vector{SBit})` | L2 Norm             | None       |

# Internal details

See [`SBitstream` operator internals](@ref) for the internals of `SBit` simulation.