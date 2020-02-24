using BitSAD
using Makie, DataStructures
using Statistics: mean
using LinearAlgebra

struct IterativeSVD
    rows::Int
    cols::Int
end

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

N = 10
T = 20000
m = 2
n = 2

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