# Quick start

BitSAD allows you to write programs that operate on bitstreams. A bitstream is a sequence of single bit values that represents some data. The following tutorial will help you get started with BitSAD if you already have familiarity with bitstream computing. For a more detailed tutorial, see [stochastic bitstreams 101](#).
<!-- There are two types of bitstreams in BitSAD — stochastic bitstreams ([`SBitstream`](@ref)) and deterministic bitstreams ([`DBitstream`](@ref)). -->

Currently, BitSAD defines [`SBitstream`](#) to refer to bit sequences found in [stochastic computing](https://en.wikipedia.org/wiki/Stochastic_computing). Such bitstreams are modeled as a Bernoulli sequence whose mean is the true number being encoded.
<!-- Deterministic bitstreams refer to [pulse density modulated](https://en.wikipedia.org/wiki/Pulse-density_modulation) audio data. In this case, the density of high bits is proportional to the amplitude of the audio signal. -->

## Creating and working with bitstreams

Creating a stochastic bitstream variable is straightforward:

{cell=getting-started}
```julia
using BitSAD

x = SBitstream(0.1)
```

Here `x` is a stochastic bitstream representing the real number 0.1. We can do arithemetic with `SBitstream`s:

{cell=getting-started}
```julia
y = SBitstream(0.3)
x + y
```

We can see that the result of `x + y` has an encoded value of `0.4 == 0.1 + 0.3`. This can be taken further to write more complex functions of bitstreams:

{cell=getting-started}
```julia
f(x, y) = x + y
g(a, b) = a * b
h(x, y, z) = f(x, y) .- g(y, z)

x, y, z = SBitstream(0.1), SBitstream(0.3), SBitstream(0.2)
result = h(x, y, z)
@show float(result) == h(float(x), float(y), float(z))
result
```

## Simulating bitstreams

You may have noticed that the printing of `result` above had the phrase "0 bits enqueue." Until now, the value of each `SBitstream` (e.g. `float(result)`) is the exact mean of the underlying Bernoulli distribution. This is not how functions of bitstreams are computed in hardware. In reality, the hardware would process a sample drawn from each of the input bitstreams. You can simulate this behavior with BitSAD:

{cell=getting-started}
```julia
num_samples = 10_000
hsim = simulatable(h, x, y, z)

for _ in 1:num_samples
    push!(result, pop!(hsim(h, x, y, z)))
end

@show abs(estimate(result) - float(result))
result
```

[`simulatable`](#) creates a simulation object which can be called just like our original function `h` (except we must pass in `h` as the first argument). We simulate `num_samples` evaluations, drawing from the distributions for `x`, `y`, and `z`, simulating the hardware on those samples, and pushing the resulting output sample onto `result`. Finally, we see that the emprical estimate of `result` is quite close to the true mean and that `result` now contains 10,000 samples in queue.
