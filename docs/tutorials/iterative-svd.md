# Complex functions of bitstreams

So far, we worked with relatively simple functions of `SBitstream`s that could be simulated and mapped to hardware manually. In this tutorial, we will look at a more complex example, the power iteration singular value decomposition algorithm of a matrix.

## Power iteration for SVD

The [singular value decomposition](https://en.wikipedia.org/wiki/Singular_value_decomposition) (SVD) is a fundamental decomposition in linear algebra. Solutions to many problems can be expressed using the SVD and its components. We won't go into too much detail about this algorithm or its applications (you could read [our paper](https://dl.acm.org/doi/10.1145/3316482.3326355)). Instead, we will focus on how to implement the algorithm in BitSAD. First, let's take a look at the power iteration itself.

```math
\begin{aligned}
\text{Step 1:} \qquad w_k & \gets A v_{k - 1} \\
\text{Step 2:} \qquad u_k & \gets w_k / \|w_k\|_2 \\
\text{Step 3:} \qquad z_k & \gets A^\top v_{k - 1} \\
\text{Step 4:} \qquad \sigma_k & \gets \|z_k\|_2 \\
\text{Step 5:} \qquad v_k & \gets z_k / \sigma_k
\end{aligned}
```

The algorithm above is repeated for ``T`` iterations. ``A``, ``v_k``, and ``u_k`` are all matrices or vectors, and ``\| \cdot \|_2`` denotes the L2-norm of a vector. While this might seem very complex compared to our examples in the previous tutorials, BitSAD will make implementing these five steps easy.

## Define the power iteration function

We begin by defining the five steps as a plain function in Julia:

{cell=iterative-svd}
```julia
using BitSAD
using LinearAlgebra

function power_iteration(A::Matrix, v₀::Vector)
    w = A * v₀
    wscaled = w .÷ sqrt(size(A, 1))
    u = wscaled ./ norm(wscaled)

    z = permutedims(A) * u
    zscaled = z .÷ sqrt(size(A, 2))
    σ = norm(zscaled)
    v = zscaled ./ σ

    return u, v, σ
end
```

The function `power_iteration` is almost an exact copy of the mathematical algorithm, except we do some additional scaling to `w` and `z`. We'll see why in a moment. For now, let's test it on a random matrix to see if it works as expected.

{cell=iterative-svd}
```julia
# use a 2x2 matrix
m, n = (2, 2)

# example matrix
A_float = [ -0.99009   0.954132;
            -0.148342  0.139824]
v₀_float = [0.5, 0.5] # v should be a unit vector

# compute the SVD for the floating point A
svddecomp = svd(A_float)

A = SBitstream.(A_float)
v₀ = SBitstream.(v₀_float)

function run_power_iteration(A, v₀; T = 5)
    u = similar(A, size(A, 1))
    σ = 0.0
    v = deepcopy(v₀)
    for k in 1:T
        u, v, σ = power_iteration(A, v)
    end

    return u, v, σ
end

u, v, σ = run_power_iteration(A, v₀)

println("u error: $(float.(u) - svddecomp.U[1, :])")
println("v error: $(float.(v) - svddecomp.V[1, :])")
println("σ error: $(float(σ) * sqrt(n) - svddecomp.S[1])")
```

Unfortunately, our result is incorrect, but we can see that BitSAD reported saturation occuring several times. Let's try this again, but now, we'll pre-scale `A` so that none of the operations in the algorithm saturate (more details on the choice of scaling are in [our paper](https://www.frontiersin.org/articles/10.3389/fnins.2018.00115/full)). Note that this is also the reason why we scaled `w` and `z` in the original function (so that `norm(w)` did not saturate).

{cell=iterative-svd}
```julia
α = 2 * max(norm(A_float, Inf), norm(A_float, 1))
A_float .= A_float ./ α

A = SBitstream.(A_float)

u, v, σ = run_power_iteration(A, v₀)

println("u error: $(float.(u) - svddecomp.U[1, :])")
println("v error: $(float.(v) - svddecomp.V[1, :])")
println("σ error: $(float(σ) * α * sqrt(n) - svddecomp.S[1])")
```

Without saturation, our results are more accurate.

## Simulating the power iteration

The test above only verified that the basic algorithm worked with the limited numeric range of stochastic bitstreams. It did not verify that bit-level operations would converge as well. Let's try that next.

{cell=iterative-svd}
```julia
using DataStructures

# simulate for T iterations
T = 10_000

# record the error on each iteration
ϵ = zeros(T)

# record the most recent 100 samples of each output
ubuffer = CircularBuffer{Vector{Int}}(100)
vbuffer = CircularBuffer{Vector{Int}}(100)
σbuffer = CircularBuffer{Int}(100)

# add a decorrelator on the feedback path
function power_iteration_fb(A, v)
    u, v, σ = power_iteration(A, v)

    return u, decorrelate.(v), σ
end

sim = simulatable(power_iteration_fb, A, v₀)
for t in 1:T
    # evaluate module
    output = sim(power_iteration_fb, A, v₀)

    # accumulate results in buffer
    global u = estimate!(ubuffer, output[1])
    global v = estimate!(vbuffer, output[2])
    global σ = estimate!(σbuffer, output[3])

    # feedback output after t = 1000
    (t >= 1000) && push!.(v₀, pop!.(output[2]))

    # record loss
    ϵ[t] = norm(α * (A_float * v - u * σ * sqrt(n)))
end

u = estimate(ubuffer)
v = estimate(vbuffer)
σ = estimate(σbuffer) * α * sqrt(n)

println("final error: $(ϵ[end])")
```

Since we are simulating bits, we need to store the bits in order to compute an estimate of the current simulation output. We use a `CircularBuffer` from DataStructures.jl to do this. Additionally, in the previous section, we directly fed back the output, `v`, as an input in the subsequent iteration. Now, `v` is unstable during the first few iterations, so we only start the feedback after 1,000 iterations. Finally, we measure the output error using the formula

```math
Av = \sigma u
```

Any valid SVD will satisfy this property. Our error is how closely this property holds for our current estimates. We chose to use this error to illustrate how [`estimate!`](#) can be used to mix floating point and bitstream computation.

## Generating hardware for the power iteration

Since our function is working at the bit-level, the next step is to generate Verilog for it.

{cell=iterative-svd}
```julia
power_iteration_verilog, _ = generatehw(power_iteration, A, v₀)
# print only the first 60 lines
println(join(split(power_iteration_verilog, "\n")[1:60], "\n"))
```

This is great, but we see that BitSAD interprets `sqrt(size(A, 1))` in our function as a constant. In hardware, we could not compute the array size on the fly. Instead, it would be a parameter of the circuit. To replicate this behavior in BitSAD, we need to use a struct.

{cell=iterative-svd}
```julia
struct PowerIteration
    scalew::Float64
    scalez::Float64
end
PowerIteration(; nrows, ncols) = PowerIteration(sqrt(nrows), sqrt(ncols))

function (circuit::PowerIteration)(A, v₀)
    w = A * v₀
    wscaled = w .÷ circuit.scalew
    u = wscaled ./ norm(wscaled)

    z = permutedims(A) * u
    zscaled = z .÷ circuit.scalez
    σ = norm(zscaled)
    v = zscaled ./ σ

    return u, v, σ
end
```

Here, we created the `PowerIteration` struct which can be instantiated with the matrix size like `PowerIteration(m, n)`. We made the struct callable, and the body of the function is nearly the same as `power_iteration`.  The only difference is that we use `circuit.scalew` instead of `sqrt(size(A, 1))` (same for the number of columns). We can generate harware for `PowerIteration` just like we did for regular functions, but now any accesses to the fields of the `PowerIteration` struct will be treated like parameters in Verilog.

{cell=iterative-svd}
```julia
circuit = PowerIteration(nrows = size(A, 1), ncols = size(A, 2))
power_iteration_verilog, _ = generatehw(circuit, A, v₀)

# print only the first 60 lines
println(join(split(power_iteration_verilog, "\n")[1:60], "\n"))
```

We can see that the generated Verilog contains `scalew` and `scalez` as parameters, and BitSAD automatically determined the fixed point binary values for them.
