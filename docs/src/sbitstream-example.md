# Walking through an `SBitstream` Example

Now let's walk through an `SBitstream` example program to compute the iterative SVD of a matrix. Here's an overview of the mathematical algorithm:

**Input:** Matrix ``A`` and inital guess ``v_0`` \
**Steps: (for ``T`` iterations)** \
1. ``w_k \gets Av_{k - 1}``
2. ``u_k \gets w_k / \|w_k\|_2``
3. ``z_k \gets A^\top v_{k - 1}``
4. ``\sigma_k \gets \|z_k\|_2``
5. ``v_k \gets z_k / \sigma_k``
**Return:** First singular value and vectors, ``\sigma_T, u_T, v_T``

First we import BitSAD and create a module for our algorithm. There is no fixed way for defining an algorithm, but we recommend defining a struct. This way, the fields of the struct represent the submodules and internal parameters of the algorithm.

```julia
using BitSAD

struct IterativeSVD
    rows::Int
    cols::Int
end
```

Above, we created the `IterativeSVD` module that is parameterized by the number of rows and columns in the matrix. Structs in Julia are callable, which means we can call the module like a function.

```julia
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
```

Here we defined the algorithm as accepting a matrix of `SBit`s and a vector of `SBit`s. Though directly operating on `SBitstream`s is supported, this is mostly intended for REPL-style work. If you are writing a program that you intend to map to hardware, it should operate directly on `SBit`s. This should be intuitive — a stochastic bitstream circuit operates on a single bit at a time. In this way, you should aim for your modules to describe what happens in a single iteration. Lastly, it is also worth noting here how closely the function body matches the algorithm above.

That's all it takes to define a bitstream computing algorithm in BitSAD. Of course, we don't just want to define the algorithm, we want to test and use it! To do that, we'll need to create some test matrices.

```julia
using Makie, DataStructures
using Statistics: mean
using LinearAlgebra

N = 10     # number of trials
T = 20000  # length of each trial
m = 2      # number of rows in matrix
n = 2      # number of columns in matrix

# generate inputs
A = [2 .* rand(m, n) .- 1 for i in 1:N]
v₀ = [rand(n) for i in 1:N]
v₀ .= v₀ ./ norm.(v₀)
dut = [IterativeSVD(m, n) for i in 1:N]

# calculate scaling
α = 2 .* max.(norm.(A, Inf), norm.(A, 1))
A = A ./ α

# convert to bitstream
A = SBitstream.(A)
v₀ = SBitstream.(v₀)
```

The code above generates an array of matrices to decompose and initial guesses. It also calculates a scaling factor to prevent the stochastic bitstreams from saturating when we run multiple iterations of the algorithm. This is an important consideration for stochastic computing, and BitSAD can allow users to empirical determine the correct scaling level. In this case, we determined theoretical scaling factors beforehand. If a bitstream variable was to saturate during computation, then BitSAD will print a warning out. In the last few lines, we take the floating-point matrices and vectors that we generated, and we create `SBitstream` objects out of them.

```julia
# eval loop
BitSAD.clearops()
ϵ = zeros(T, N)
ubuffer = [CircularBuffer{Vector{Int}}(5000) for i in 1:N]
vbuffer = [CircularBuffer{Vector{Int}}(5000) for i in 1:N]
σbuffer = [CircularBuffer{Int}(5000) for i in 1:N]
Threads.@threads for trial in 1:N
    generate!.(A[trial], T)
    generate!.(v₀[trial], 1000)

    for t in 1:T
        # evaluate module
        output = dut[trial](pop!.(A[trial]), pop!.(v₀[trial]))
        (t >= 1000) && push!.(v₀[trial], decorrelate.(output[2]))

        # accumulate results in buffer
        u = estimate!(ubuffer[trial], output[1])
        v = estimate!(vbuffer[trial], output[2])
        σ = estimate!(σbuffer[trial], output[3])

        # record loss
        ϵ[t, trial] = norm(α[trial] * (float.(A[trial]) * v - u * σ * sqrt(n)))
    end

    println("Completed trial $trial")
end
```

The loop above is the actual test loop. The line `BitSAD.clearops()` resets the internal data structures utilized by BitSAD. It is not required in this case, but it can be good practice to make sure no previous operations conflict with what is about to be run. For more information on this see [Internals](@ref).

We also instantiated some `CircularBuffer`s to keep track of the last 5000 bit samples of each output bitstream. This is not required, but we often want to keep a running windowed average of a bitstream to see if the empirical average matches the true real number the bitstream should encode.

Next, we called `generate!` on the matrix and vector that is the input for this trial. This will sample from the Bernoulli distribution that models each bitstream and push the samples onto their queues. Recall from [Operating on Bitstreams](@ref) that this is not required, but pre-generating the samples can improve performance for lengthy trials.

Finally, we enter the main loop that runs over `T` iterations and exercises an `IterativeSVD` for each step. The line `dut[trial](pop.!(A[trial]), pop!.(v₀[trial]))` is how we call our struct. If we weren't running for many trials, we wouldn't have multiple objects, and the call might look more like `dut(pop!.(A), pop!.(v₀))`. This call produces `output` which is the tuple returned by our algorithm. One element of this tuple, ``v_k``, is passed back into our algorithm as an input. We can pass each returned vector or scalar `SBit` to the `estimate!` function from BitSAD. This function is a handy utility function that updates the circular buffers and returns the current empirical average. The last step of the loop body is to compute and store the current algorithm error.

```julia
u = @. estimate!(ubuffer)
v = @. estimate!(vbuffer)
σ = @. estimate!(σbuffer) * sqrt(n)
A = map(λ -> float.(λ), A)
f = svd(A[1])
println("u error: $(u[1] - f.U[1, :])")
println("v error: $(v[1] - f.V[1, :])")
println("σ error: $(σ[1] - f.S[1])")
println("  error: $(mean(norm.(α .* (A .* v .- u .* σ))))")
scene = lines(dropdims(mean(ϵ; dims = 2); dims = 2), color = :blue)
axis = scene[Axis]
axis[:names][:axisnames] = ("Iteration #", "Loss")
scene = title(scene, "Iterative SVD Loss Over $T Iterations", textsize = 15)

scene
```

Once the simulation is run, we can use the code above to examine the results. `u = @. estimate!(ubuffer)` returns the current average in the circular buffer. The rest of the code is not specific to BitSAD, instead it is just some plotting code to visualize the error over the `T` iterations.

## Notes and Considerations

The purpose of this example is not to teach you about bitstream computing or explain every function call. Rather it is walk through the high level process of designing a BitSAD program. See [Bitstreams](@ref) for more information on the `SBitstream` type and operators on them.

You may have notice we glossed over the `(t >= 1000) && push!.(v₀[trial], decorrelate.(output[2]))` line. Normally, we cannot directly feedback an output of a bitstream computing algorithm into its inputs. This would violate a critical assumption of stochastic computing. Instead, we pass the output through a decorrelator which is a hardware unit that creates a new i.i.d. bitstream from its input. In BitSAD, this is done by calling the `decorrelate` function. We then push the decorrelated bit sample onto `v₀[trial]`'s queue. Notice that we only do this for `t >= 1000`. This is for stability reasons. It allows the algorithm to receive a stable input for a 1000 iterations before we allow continuous feedback.