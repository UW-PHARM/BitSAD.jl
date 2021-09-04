# Stochastic bitstreams 101

A stochastic bitstreams, ``X_t``, is a sequence of samples from a Bernoulli distribution:
```math
X_t \sim \mathrm{Ber}(p)
```
where ``p`` is the underlying value being encoded. Stochastic bitstreams are the data format used in [stochastic computing](https://en.wikipedia.org/wiki/Stochastic_computing).

So, _why stochastic bitstreams?_ You can refer to [Gaines' original work](http://pages.cpsc.ucalgary.ca/~gaines/reports/COMP/SCS69/SCS69.pdf) on the topic, but in short, stochastic computing systems tend to be much more area and power efficient compared to traditional binary systems. The reason for this is that any hardware operation on stochastic bitstreams must only process a single bit at a time, and this can often be done in a "streaming" fashion (eliminating the need for sequential logic).

Take multiplication as an example. For numbers represented in floating point binary, multiplication can be an expensive hardware operation. In many ultra-low power systems, floating-point multiplication is evaluated over multiple clock cycles with integer arithemetic units. In contrast, a stochastic computing multiplier is a single AND gate. In the next section, you'll see why this is the case.

## Basics of stochastic bitstreams

First, let's try creating a stochastic bitstream.

{cell=sbitstream-101}
```julia
using BitSAD

x = SBitstream(0.3)
```

Here, we created a [`SBitstream`](#) (the type in BitSAD for stochastic bitstreams) encoding the real value 0.3. `SBitstream` will keep track of the mean of the Bernoulli distribution, which we can recover with [`float`](#).

{cell=sbitstream-101}
```julia
float(x)
```

You'll also notice that there were "0 bits enqueue" in `x`. This refers to the fact that the bitstream, `x`, is a sequence of samples. Currently, we have not drawn any samples from `x`. We can try that now:

{cell=sbitstream-101}
```julia
xt = pop!(x)
```

Now, we have a single sample, `xt`, which is of type [`SBit`](#). An `SBit` is a "stochastic bit" which is just a convenient alias for a [`NamedTuple`](https://docs.julialang.org/en/v1.6/manual/functions/#Named-Tuples) with two parts --- the positive part ([`pos`](#)) and the negative part ([`neg`](#)).

> Wait, I thought stochastic bitstreams were a single bit sequence? \
>     --- You (probably)

Yes, in theory, but this definition means that we can only represent real numbers ``p \in [0, 1]``. In practice, we would like to represent signed numbers (though we still normalize them to ``p \in [-1, 1]``). BitSAD uses a two-channel format for encoding signed numbers as two underlying bitstreams. One channel is the positive part and the other is the negative part, such that
```math
p = \mathbb{E} \left[ \mathrm{Pos}(X_t) - \mathrm{Neg}(X_t) \right]
```
Samples from these two separate channels are neatly packaged into a single `SBit` so that we can think of `SBitstream`s as a sequence of `SBit`s without having to worry too much about the underlying signed encoding scheme.

If we want, we can even add `SBit`s onto a `SBitstream`.

{cell=sbitstream-101}
```julia
push!(x, xt)
x
```

We see that `x` now has a single bit in queue. For convenience, BitSAD provides [`generate!`](#) to pre-load a `SBitstream` with samples from the underlying distributions.

{cell=sbitstream-101}
```julia
generate!(x) # add a single sample
@show length(x)
generate!(x, 1000)
x
```

Finally, we can see that the empirical average over the `SBit`s in queue matches to encoded value quite closely.

{cell=sbitstream-101}
```julia
abs(estimate(x) - float(x))
```

## Operations on `SBitstream`s

So far, we have not computed any meaningful results with BitSAD. Let's go back to the multiplication example and try to multiply two `SBitstream`s.

{#sbitstream-101-z cell=sbitstream-101}
```julia
y = SBitstream(0.5)
z = x * y
```

The result, `z`, has an encoded value of `0.15 = 0.3 * 0.5`. Recall that stochastic bitstreams encode the value in the mean of their underlying distributions. Any function on applied to `SBitstream`s is implying a function over their means. Thus,
```math
\mathbb{E} [Z_t] = \mathbb{E} [X_t] \mathbb{E} [Y_t]
```
We can verify this in BitSAD too.

{cell=sbitstream-101}
```julia
float(z) == float(x) * float(y)
```

So far, we haven't described how this multiplication is actually executed on hardware. Certainly, multiplying the floating point means then drawing from the resulting distribution would be no better than traditional arithemetic. Stochastic computing takes advantage of the fact that ``X_t`` and ``Y_t`` are independent to note that
```math
\mathbb{E} [Z_t] = \mathbb{E} [X_t] \mathbb{E} [Y_t] = \mathbb{E} [X_t Y_t]
```
In other words, we can multiply the samples at step `t` from each sequence to create a new sequence. The mean of this new sequence should match ``\mathbb{E} [Z_t]``. Let's see it in action.

{cell=sbitstream-101}
```julia
multiply_sbit(x, y) = SBit((pos(x) * pos(y), neg(x) * neg(y)))

num_samples = 1000
for t in 1:num_samples
    xbit, ybit = pop!(x), pop!(y)
    zbit = multiply_sbit(xbit, ybit)
    push!(z, zbit)
end

abs(estimate(z) - float(z))
```

We used a helper function, `multiply_sbit` to multiply the positive and negative channel of each `SBit` separately. This resulted in a new `SBit`, `zbit`, which we pushed onto `z`. When we take the empirical average of all these `zbit`s, we see that it is close to the true mean of `z`.

Hopefully, you can now see why stochastic computing can be so resource efficient. Each channel of `multiply_sbit` only needed to multiply two 1-bit numbers. This can be done with a single AND gate.

In the next tutorial, you'll see how to automate the `SBit`-level simulation we did above, and how to generate synthesizable hardware from a Julia function.
