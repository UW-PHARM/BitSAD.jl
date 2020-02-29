# Deterministic Bitstreams

A `DBitstream` is a sequence of `DBit`s representing PDM encoded audio.

```@docs
DBit
DBitstream
```

A `DBit` maps ``\{0, 1\} \mapto \{-1, 1\}``. We can access this mapping through `float`.

```@docs
float
```

# Operators

The following operations are defined for `DBit`s. _Note that they are not defined for `DBitstream`_.

| Operation               | Name                |
| :---------------------- | :------------------ |
| `+(x::DBit, y::DBit)`   | Addition            |
| `+(x::DBit, y::Real)`   | Addition            |
| `+(x::Real, y::DBit)`   | Addition            |
| `-(x::DBit, y::DBit)`   | Subtraction         |
| `-(x::DBit, y::Real)`   | Subtraction         |
| `-(x::Real, y::DBit)`   | Subtraction         |
| `*(x::DBit, y::DBit)`   | Multiplication      |
| `*(x::DBit, y::Real)`   | Multiplication      |
| `*(x::Real, y::DBit)`   | Multiplication      |
| `/(x::DBit, y::DBit)`   | Division            |
| `/(x::DBit, y::Real)`   | Division            |
| `/(x::Real, y::DBit)`   | Division            |
