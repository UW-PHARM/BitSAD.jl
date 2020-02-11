using Base: @kwdef

abstract type SOperator end

@kwdef mutable struct SDecorrelator
    stepval::Int = 16
    rngrange::Int = 255
    buffer::CircularBuffer{Bool} = CircularBuffer{Bool}(2)
    counter::Int = 0
    rng::MersenneTwister = MersenneTwister(rand(UInt))

    function SDecorrelator(stepval, rngrange, buffer, counter, rng)
        decorr = new(stepval, rngrange, buffer, counter, rng)
        fill!(decorr.buffer, false)

        return decorr
    end
end
function (op::SDecorrelator)(x::Bool)
    # Increment counters
    op.counter += op.stepval * x

    # Decide output
    z = pop!(op.buffer)
    r = rand(op.rng, 0:op.rngrange)
    if r <= op.counter
        push!(op.buffer, true)
    else
        push!(op.buffer, false)
    end

    # Decrement counters
    op.counter = max(op.counter - op.stepval * z, 0)

    return z
end

"""
    SSignedDecorrelator

A stochastic bitstream decorrelator.
"""
@kwdef struct SSignedDecorrelator <: SOperator
    pdecorr::SDecorrelator = SDecorrelator()
    ndecorr::SDecorrelator = SDecorrelator()
end
(op::SSignedDecorrelator)(x::SBit) = (op.pdecorr(pos(x)), op.ndecorr(neg(x)))

@kwdef mutable struct SAdder
    counter::Int = 0
end
function (op::SAdder)(x::Bool, y::Bool)
    # Increment counter
    op.counter += x + y

    # Decide output
    z = (op.counter >= 1)

    # Decrement counter
    op.counter = max(op.counter - z, 0)

    return z
end

"""
    SSignedAdder

A signed stochastic bitstream add operator.
"""
@kwdef struct SSignedAdder <: SOperator
    padder::SAdder = SAdder()
    nadder::SAdder = SAdder()
end
function (op::SSignedAdder)(x::SBit, y::SBit)
    pbit = op.padder(pos(x), pos(y))
    nbit = op.nadder(neg(x), neg(y))

    return (pbit, nbit)
end

@kwdef mutable struct SSaturatingSubtractor
    counter::Int = 0
end
function (op::SSaturatingSubtractor)(x::Bool, y::Bool)
    # # Increment counter
    # op.counter += (xor(x, y) && y) - (xor(x, y) && x)

    # # Saturate counters
    # op.counter = max(op.counter, 0)

    # # Decide output
    # z = (op.counter == 0 && x && !y)

    op.counter += x - y

    z = (op.counter >= 1)

    op.counter = max(op.counter - z, 0)

    return z
end

"""
    SSignedSubtractor

A signed stochastic bitstream subtract operator.
"""
@kwdef struct SSignedSubtractor <: SOperator
    padder::SAdder = SAdder()
    nadder::SAdder = SAdder()
    ppsub::SSaturatingSubtractor = SSaturatingSubtractor()
    pnsub::SSaturatingSubtractor = SSaturatingSubtractor()
    npsub::SSaturatingSubtractor = SSaturatingSubtractor()
    nnsub::SSaturatingSubtractor = SSaturatingSubtractor()
end
function (op::SSignedSubtractor)(x::SBit, y::SBit)
    pp = op.ppsub(pos(x), pos(y))
    pn = op.pnsub(pos(y), pos(x))
    np = op.npsub(neg(y), neg(x))
    nn = op.nnsub(neg(x), neg(y))
    z = (op.padder(pp, np), op.nadder(pn, nn))

    return z
end

struct SMultiplier end
(op::SMultiplier)(x::Bool, y::Bool) = x & y

"""
    SSignedMultiplier

A signed stochastic bitstream multiply operator.
"""
@kwdef struct SSignedMultiplier <: SOperator
    ppmult::SMultiplier = SMultiplier()
    pnmult::SMultiplier = SMultiplier()
    npmult::SMultiplier = SMultiplier()
    nnmult::SMultiplier = SMultiplier()
    sub11::SSaturatingSubtractor = SSaturatingSubtractor()
    sub12::SSaturatingSubtractor = SSaturatingSubtractor()
    sub13::SSaturatingSubtractor = SSaturatingSubtractor()
    sub14::SSaturatingSubtractor = SSaturatingSubtractor()
    padder::SAdder = SAdder()
    nadder::SAdder = SAdder()
end
function (op::SSignedMultiplier)(x::SBit, y::SBit)
    pp = op.ppmult(pos(x), pos(y))
    pn = op.pnmult(pos(x), neg(y))
    np = op.npmult(neg(x), pos(y))
    nn = op.nnmult(neg(x), neg(y))

    s₁₁ = op.sub11(pp, pn)
    s₁₂ = op.sub12(pn, pp)
    s₁₃ = op.sub13(np, nn)
    s₁₄ = op.sub14(nn, np)

    z = (op.padder(s₁₁, s₁₄), op.nadder(s₁₂, s₁₃))

    return z
end

@kwdef mutable struct SDivider
    counter::Int = 0
    zand::Bool = false
    rng::MersenneTwister = MersenneTwister(rand(UInt))
end
function (op::SDivider)(x::Bool, y::Bool)
    # Update counter
    op.counter = max(op.counter + 2 * x - 2 * op.zand, -100)

    # Decide output
    r = rand(op.rng, 0:64)
    z = (op.counter > r)

    # Update zand
    op.zand = z && y

    return z
end

"""
    SSignedDivider

A signed stochastic bitstream divide operator.
"""
@kwdef struct SSignedDivider <: SOperator
    pdiv::SDivider = SDivider()
    ndiv::SDivider = SDivider()
    psub::SSaturatingSubtractor = SSaturatingSubtractor()
    nsub::SSaturatingSubtractor = SSaturatingSubtractor()
end
function (op::SSignedDivider)(x::SBit, y::SBit)
    pp = op.pdiv(pos(x), pos(y))
    np = op.ndiv(neg(x), pos(y))

    z = (op.psub(pp, np), op.nsub(np, pp))

    return z
end

"""
    SFixedGainDivider

A stochastic bitstream fixed gain divide operator.
"""
@kwdef mutable struct SFixedGainDivider <: SOperator
    counter::Int = 0
end
function (op::SFixedGainDivider)(x::SBit, y::Real)
    # Update counter
    op.counter += 255 * pos(x)

    # Decide output
    z = (op.counter >= round(255 * y))

    # Decrement counter
    op.counter -= z * round(255 * y)

    return (z, false)
end

"""
    SSquareRoot

A stochastic bitstream square root operator.
"""
@kwdef mutable struct SSquareRoot <: SOperator
    counter::Int = 0
    zand::Bool = false
    buffer::CircularBuffer{Bool} = CircularBuffer{Bool}(1)
    rng::MersenneTwister = MersenneTwister(rand(UInt))

    function SSquareRoot(counter, zand, buffer, rng)
        op = new(counter, zand, buffer, rng)
        fill!(op.buffer, false)

        return op
    end
end
function (op::SSquareRoot)(x::SBit)
    # Update counter
    op.counter = max(op.counter + 4 * pos(x) - 4 * op.zand, -100)

    # Decide output
    r = rand(op.rng, 0:511)
    z = (op.counter >= r)

    # Update zand
    op.zand = z && pop!(op.buffer)
    push!(op.buffer, z)

    return (z, false)
end

struct SMatMultiplier
    counters::Array{Int, 2}
end
SMatMultiplier(nrows, ncols) = SMatMultiplier(zeros(nrows, ncols))
function (op::SMatMultiplier)(x::VecOrMat{Bool}, y::VecOrMat{Bool})
    # Increment counters
    op.counters .+= x * y

    # Decide output
    z = (op.counters .>= 1)

    # Decrement counters
    op.counters .-= z

    return z
end
(op::SMatMultiplier)(x::BitArray, y::BitArray) =
    op(convert(Array{Bool, ndims(x)}, x), convert(Array{Bool, ndims(y)}, y))

"""
    SSignedMatMultiplier

A stochastic bitstream matrix multiply operator.
"""
struct SSignedMatMultiplier <: SOperator
    ppmult::SMatMultiplier
    pnmult::SMatMultiplier
    npmult::SMatMultiplier
    nnmult::SMatMultiplier
    sub1::Array{SSaturatingSubtractor, 2}
    sub2::Array{SSaturatingSubtractor, 2}
    sub3::Array{SSaturatingSubtractor, 2}
    sub4::Array{SSaturatingSubtractor, 2}
    padder::Array{SAdder, 2}
    nadder::Array{SAdder, 2}
end
SSignedMatMultiplier(nrows, ncols) =
    SSignedMatMultiplier(
        SMatMultiplier(nrows, ncols),
        SMatMultiplier(nrows, ncols),
        SMatMultiplier(nrows, ncols),
        SMatMultiplier(nrows, ncols),
        [SSaturatingSubtractor() for i in 1:nrows, j in 1:ncols],
        [SSaturatingSubtractor() for i in 1:nrows, j in 1:ncols],
        [SSaturatingSubtractor() for i in 1:nrows, j in 1:ncols],
        [SSaturatingSubtractor() for i in 1:nrows, j in 1:ncols],
        [SAdder() for i in 1:nrows, j in 1:ncols],
        [SAdder() for i in 1:nrows, j in 1:ncols]
    )
function (op::SSignedMatMultiplier)(x::VecOrMat{SBit}, y::VecOrMat{SBit})
    # println(op)
    # println()
    
    pp = op.ppmult(pos.(x), pos.(y))
    pn = op.pnmult(pos.(x), neg.(y))
    np = op.npmult(neg.(x), pos.(y))
    nn = op.nnmult(neg.(x), neg.(y))

    s₁ = map.(op.sub1, pp, pn)
    s₂ = map.(op.sub2, pn, pp)
    s₃ = map.(op.sub3, np, nn)
    s₄ = map.(op.sub4, nn, np)

    z = zip(map.(op.padder, s₁, s₄), map.(op.nadder, s₂, s₃)) |> collect

    return (size(z, 2) == 1) ? dropdims(z; dims = 2) : z
end

"""
    SL2Normer

A stochastic bitstream L2-norm operator.
"""
@kwdef struct SL2Normer <: SOperator
    dot::SSignedMatMultiplier = SSignedMatMultiplier(1, 1)
    buffer::CircularBuffer{Matrix{SBit}} = CircularBuffer{Matrix{SBit}}(1)
    root::SSquareRoot = SSquareRoot()
end
function (op::SL2Normer)(x::Vector{SBit})
    # get row vector
    dummybit = map(λ -> SBit((false, false), λ.value, λ.id), permutedims(x))
    xt = isempty(op.buffer) ? dummybit : pop!(op.buffer)
    push!(op.buffer, permutedims(x))

    # compute inner product
    xtx = op.dot(xt, x)[1]

    # compute root
    z = op.root(SBit(xtx, x[1].value, x[1].id))

    return z
end