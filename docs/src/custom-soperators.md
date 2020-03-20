# `SBitstream` operator internals

As mentioned in the sections on `SBitstream`s, a stochastic operation is a _stateful_. This means that each operator is not pure in the functional programming sense. Instead, an operator is actually an object with state that is unique to each set of inputs in a particular program. So, simulating `SBitstream`s accurately requires a call like `x + y` to create a new `+` object that is invoked whenever `x + y` is called, but never for any other invocation of `+` such as `z + y`.

To facilitate such behavior, we capture the uniqueness of every `SBitstream` or `SBit` with an `id` field. This field is a UUID generated when the object is created. Whenever an operator like `+` is invoked, the UUIDs of all inputs should be hashed together to produce a unique identifier for that invocation. There should be a stateful object that simulates the hardware evaluation of the operator. The hashed identifier should be used to index a dictionary that looks up an instance of this stateful object. If this is the first invocation, a stateful object should be created. The object is then called with the input `SBit` values and an output `SBit` is produced. If this is the first invocation, the `id` of the output is recorded in a dictionary indexed by the hash identifier. Otherwise, this dictionary should be used to set the `id` of the output consistently.

Whenever an operator implementation meets all these criteria, we call it _simulatable_. All operators provided for `SBit`s by BitSAD are simulatable. Below is a simulatable implementation of a stochastic add operator.

```julia
function +(x::SBit, y::SBit)
    key = (hashn!(vcat(_genidstr(x.id), _genidstr(y.id)), 4), Symbol(:+))
    if haskey(_opmap, key)
        op, id = _opmap[key]
        value = x.value + y.value

        SBit(op(x, y), value, id)
    else
        op = SSignedAdder()
        id = _genid()
        value = x.value + y.value
        outbit = SBit(op(x, y), value, id)
        _opmap[key] = (op, id)

        return outbit
    end
end
```

# Using `@simulatable`

Of course, implementing the code like above for every operator would be cumbersome and prone to error. What's `_genidstr` or `_opmap` for example? How do you use them? To alleviate these issues, BitSAD provides `@simulatable`.

```@docs
BitSAD.@simulatable
```