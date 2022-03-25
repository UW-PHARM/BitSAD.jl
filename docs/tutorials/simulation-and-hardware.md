# Simulating and generating hardware in BitSAD

In [stochastic bitstreams 101](#), we multiplied two `SBitstream`s manually in a loop. This can be cumbersome for complex functions involving many inputs and outputs. A key feature of BitSAD is the automation of this step which we will explore in the following tutorial. As a bonus, you'll see how the same principles enable automatic [Verilog](https://en.wikipedia.org/wiki/Verilog) generation to create hardware for your functions.

## Simulating functions on `SBitstream`s

Suppose we have the following function, `f`, which multiplies two `SBitstream`s.

{cell=sim-and-hw}
```julia
using BitSAD

f(x, y) = x * y

x, y = SBitstream(0.3), SBitstream(0.5)
z = f(x, y)
```

We see that the output, `z`, is similar to the [previous tutorial](# "sbitstream-101-z"). Instead of manually simulating the bit-level multiplication in `f`, we can use [`simulatable`](#).

{cell=sim-and-hw}
```julia
fsim = simulatable(f, x, y)
fsim(f, x, y)
```

`fsim` is a Julia function that can be called similar to `f` (the exception being that `fsim` expects the first argument to be the function to simulate, `f`).

!!! tip
    For static functions like `f`, it may see redundant to pass `f` in. But the simulated function can be a [callable struct](https://docs.julialang.org/en/v1.6/manual/methods/#Function-like-objects) as well. This means that you can modify the struct between invocations of the simulation object if you desire.

BitSAD generates `fsim` by executing `f(x, y)` once and storing the program execution on a trace. This trace gets transformed into a similar program except calls to operations are replaced by calls to simulators. These simulators emulate the bit-level execution, similar to `multiply_sbit` from the previous tutorial.

Let's verify that `fsim` works like our manual simulation from before.

{cell=sim-and-hw}
```julia
num_samples = 1000
foreach(1:num_samples) do t
    push!(z, pop!(fsim(f, x, y)))
end

abs(estimate(z) - float(z))
```

What's actually happening inside `fsim`? We can take a peek under the hood with [`show_simulatable`](#) which will print out the Julia function being compiled by BitSAD.

{cell=sim-and-hw}
```julia
BitSAD.show_simulatable(f, x, y)
```

Here, we see that `fsim` is a function that accepts two `SBitstream{Float64}`s as input. Walking through each step, we see:

1. `x3 = getbit(x2)` pops a sample from the first input (similarly, `x5 = getbit(x4)`).
2. The regular `*(x2, x4)` is called on our input `SBitstream`s to produce the output `SBitstream`, `x6`.
3. A simulator, `SSignedMultiplier` is called on the popped bits, `x3` and `x4`.
4. The resulting `SBit`, `x7`, is pushed onto the output bitstream with `setbit!(x6, x7)`.

These four steps are the basic transformation applied to any simulatable operation on the trace.

### Single evalutaion

When writing software, it is reasonable to execute the same function twice on the same set of inputs.

{cell=sim-and-hw}
```julia
g(a, b) = a + b
h(x, y) = g(x, y) * g(x, y)
z = h(x, y)
```

`h` calls `g(x, y)` twice, and as we can see it causes no issues when running the code. In hardware, `g` is a stateful operator, so it cannot be called twice, since multiple invocations will produce different outputs. Instead, we want to re-use the first evaluation of `g(x, y)`. BitSAD does this automatically.

{cell=sim-and-hw}
```julia
BitSAD.show_simulatable(h, x, y)
```

Examining the compiled function, we see that only a single `SSignedAdder` is invoked on the inputs. The same resulting bit, `x7`, is passed to the final `SSignedMultiplier`.

### Applying decorrelation

Recall from [stochastic bitstreams 101](# "Operations on `SBitstream`s") that stochastic computing operators exploit the statistical independence of their inputs. But in the previous section, we can see clearly that `hsim` does not pass independent inputs to the `SSignedMultiplier` (it's the _exact same_ bit!). So, we should expect incorrect results

{cell=sim-and-hw}
```julia
z = h(x, y)
hsim = simulatable(h, x, y)
for t in 1:num_samples
    push!(z, pop!(hsim(h, x, y)))
end

abs(estimate(z) - float(z))
```

Note that the algorithmic-level of `h` had no issues (`float(z) == 0.64`), but the bit-level output has measurable error. BitSAD was designed to make spotting issues that appear at the hardware-level easier. How can we fix this? In stochastic computing circuits, we can [`decorrelate`](#) bitstreams to make them independent.

{cell=sim-and-hw}
```julia
hfixed(x, y) = g(x, y) * decorrelate(g(x, y))
z = hfixed(x, y)
hfixed_sim = simulatable(hfixed, x, y)
for t in 1:num_samples
    push!(z, pop!(hfixed_sim(hfixed, x, y)))
end

@show BitSAD.show_simulatable(hfixed, x, y)
abs(estimate(z) - float(z))
```

## Generating hardware

With BitSAD, we've been able to create functions on stochastic bitstreams, and we verified that they should work at the bit-level. The next step is to generate hardware for these functions! BitSAD can take any Julia function and generate synthesizable Verilog code.

Let's start by creating hardware for `f`.

{cell=sim-and-hw, result=false}
```julia
f_verilog, f_circuit = generatehw(f, x, y)
```

We do this by calling [`generatehw`](#) which has a similar syntax to [`simulatable`](#). It returned two values, `f_verilog` and `f_circuit`. `f_verilog` is a `String` of the Verilog code. You can write this to disk or examine it in the Julia REPL.

{cell=sim-and-hw}
```julia
print(f_verilog)
```

We see that each net has a "_p" and "_m" appended for "plus" and "minus." Recall, this is because `SBitstream`s are signed and represented by two channels. Handling these channels correctly to produce a single `SBitstream` as the output is why our hardware is so much more complex than a single AND gate. BitSAD was created to automate this complexity away.
