@kwdef mutable struct SDecorrelator{T<:Random.AbstractRNG}
    stepval::Int = 16
    rngrange::Int = 255
    buffer::CircularBuffer{Bool} = CircularBuffer{Bool}(2)
    counter::Int = 0
    rng::T = PCG.PCGStateUnique(rand(UInt))

    function SDecorrelator(stepval,
                           rngrange,
                           buffer,
                           counter,
                           rng::T) where {T<:Random.AbstractRNG}
        decorr = new{T}(stepval, rngrange, buffer, counter, rng)
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
function Base.show(io::IO, x::SDecorrelator)
    print(io, "SDecorrelator(")
    join(io, map((:stepval, :rngrange, :counter)) do field
        string(getproperty(x, field))
    end, ", ")
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SDecorrelator)
    print(io, "SDecorrelator(")
    join(io, map((:stepval, :rngrange, :counter)) do field
        string(field) * " = " * string(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

"""
    SSignedDecorrelator

A stochastic bitstream decorrelator.
"""
@kwdef struct SSignedDecorrelator
    pdecorr::SDecorrelator = SDecorrelator()
    ndecorr::SDecorrelator = SDecorrelator()
end
(op::SSignedDecorrelator)(x::SBit) = SBit((op.pdecorr(x.pos), op.ndecorr(x.neg)))
Base.show(io::IO, ::SSignedDecorrelator) = print(io, "SSignedDecorrelator(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedDecorrelator)
    print(io, "SSignedDecorrelator(")
    show(io, x.pdecorr)
    print(io, ", ")
    show(io, x.ndecorr)
    print(io, ")")
end

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
function Base.show(io::IO, x::SAdder)
    print(io, "SAdder(")
    print(io, string(x.counter))
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SAdder)
    print(io, "SAdder(counter = ")
    print(io, string(x.counter))
    print(io, ")")
end

"""
    SSignedAdder

A signed stochastic bitstream add operator.
"""
@kwdef struct SSignedAdder
    padder::SAdder = SAdder()
    nadder::SAdder = SAdder()
end
function (op::SSignedAdder)(x::SBit, y::SBit)
    pbit = op.padder(x.pos, y.pos)
    nbit = op.nadder(x.neg, y.neg)

    return SBit((pbit, nbit))
end
Base.show(io::IO, ::SSignedAdder) = print(io, "SSignedAdder(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedAdder)
    print(io, "SSignedAdder(")
    show(io, x.padder)
    print(io, ", ")
    show(io, x.nadder)
    print(io, ")")
end

@kwdef mutable struct SAverager{N}
    counter::Int = 0
end
function (op::SAverager{N})(xs::Vararg{Bool, N}) where N
    # Increment counter
    op.counter += sum(xs)

    # Decide output
    z = (op.counter >= N)

    # Decrement counter
    op.counter = max(op.counter - z * N, 0)

    return z
end
function Base.show(io::IO, x::SAverager{N}) where N
    print(io, "SAverager{$N}(")
    print(io, string(x.counter))
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SAverager{N}) where N
    print(io, "SAverager{$N}(counter = ")
    print(io, string(x.counter))
    print(io, ")")
end

"""
    SSignedAverager{N}()

A signed stochastic bitstream average operator over `N` inputs.
"""
@kwdef struct SSignedAverager{N}
    pavger::SAverager{N} = SAverager{N}()
    navger::SAverager{N} = SAverager{N}()
end
function (op::SSignedAverager{N})(xs::Vararg{SBit, N}) where N
    pbit = op.pavger(pos.(xs)...)
    nbit = op.navger(neg.(xs)...)

    return SBit((pbit, nbit))
end
Base.show(io::IO, ::SSignedAverager{N}) where N = print(io, "SSignedAverager{N}(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedAverager{N}) where N
    print(io, "SSignedAverager{N}(")
    show(io, x.pavger)
    print(io, ", ")
    show(io, x.navger)
    print(io, ")")
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
function Base.show(io::IO, x::SSaturatingSubtractor)
    print(io, "SSaturatingSubtractor(")
    print(io, string(x.counter))
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SSaturatingSubtractor)
    print(io, "SSaturatingSubtractor(counter = ")
    print(io, string(x.counter))
    print(io, ")")
end

"""
    SSignedSubtractor

A signed stochastic bitstream subtract operator.
"""
@kwdef struct SSignedSubtractor
    padder::SAdder = SAdder()
    nadder::SAdder = SAdder()
    ppsub::SSaturatingSubtractor = SSaturatingSubtractor()
    pnsub::SSaturatingSubtractor = SSaturatingSubtractor()
    npsub::SSaturatingSubtractor = SSaturatingSubtractor()
    nnsub::SSaturatingSubtractor = SSaturatingSubtractor()
end
function (op::SSignedSubtractor)(x::SBit, y::SBit)
    pp = op.ppsub(x.pos, y.pos)
    pn = op.pnsub(y.pos, x.pos)
    np = op.npsub(y.neg, x.neg)
    nn = op.nnsub(x.neg, y.neg)
    z = (op.padder(pp, np), op.nadder(pn, nn))

    return SBit(z)
end
Base.show(io::IO, ::SSignedSubtractor) = print(io, "SSignedSubtractor(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedSubtractor)
    print(io, "SSignedSubtractor(")
    join(io, map(fieldnames(SSignedSubtractor)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

struct SMultiplier end
(op::SMultiplier)(x::Bool, y::Bool) = x & y

"""
    SSignedMultiplier

A signed stochastic bitstream multiply operator.
"""
@kwdef struct SSignedMultiplier
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
    pp = op.ppmult(x.pos, y.pos)
    pn = op.pnmult(x.pos, y.neg)
    np = op.npmult(x.neg, y.pos)
    nn = op.nnmult(x.neg, y.neg)

    s₁₁ = op.sub11(pp, pn)
    s₁₂ = op.sub12(pn, pp)
    s₁₃ = op.sub13(np, nn)
    s₁₄ = op.sub14(nn, np)

    z = (op.padder(s₁₁, s₁₄), op.nadder(s₁₂, s₁₃))

    return SBit(z)
end
Base.show(io::IO, ::SSignedMultiplier) = print(io, "SSignedMultiplier(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedMultiplier)
    print(io, "SSignedMultiplier(")
    join(io, map(fieldnames(SSignedMultiplier)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
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
function Base.show(io::IO, x::SDivider)
    print(io, "SDivider(")
    print(io, string(x.counter))
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SDivider)
    print(io, "SDivider(counter = ")
    print(io, string(x.counter))
    print(io, ")")
end

"""
    SSignedDivider

A signed stochastic bitstream divide operator.
"""
@kwdef struct SSignedDivider
    pdiv::SDivider = SDivider()
    ndiv::SDivider = SDivider()
    psub::SSaturatingSubtractor = SSaturatingSubtractor()
    nsub::SSaturatingSubtractor = SSaturatingSubtractor()
end
function (op::SSignedDivider)(x::SBit, y::SBit)
    pp = op.pdiv(x.pos, y.pos)
    np = op.ndiv(x.neg, y.pos)

    z = (op.psub(pp, np), op.nsub(np, pp))

    return SBit(z)
end
Base.show(io::IO, ::SSignedDivider) = print(io, "SSignedDivider(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedDivider)
    print(io, "SSignedDivider(")
    join(io, map(fieldnames(SSignedDivider)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

@kwdef mutable struct SFixedGainDivider
    counter::Int = 0
end
function (op::SFixedGainDivider)(x::Bool, y::Real)
    # Update counter
    op.counter += 255 * x

    # Decide output
    z = (op.counter >= round(255 * y))

    # Decrement counter
    op.counter -= z * round(255 * y)

    return z
end
function Base.show(io::IO, x::SFixedGainDivider)
    print(io, "SFixedGainDivider(")
    print(io, string(x.counter))
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SFixedGainDivider)
    print(io, "SFixedGainDivider(counter = ")
    print(io, string(x.counter))
    print(io, ")")
end

"""
    SSignedFixedGainDivider

A stochastic bitstream fixed gain divide operator.
"""
@kwdef struct SSignedFixedGainDivider
    pdiv::SFixedGainDivider = SFixedGainDivider()
    ndiv::SFixedGainDivider = SFixedGainDivider()
end
(op::SSignedFixedGainDivider)(x::SBit, y::Real) = SBit((op.pdiv(x.pos, y), op.ndiv(x.neg, y)))
Base.show(io::IO, ::SSignedFixedGainDivider) = print(io, "SSignedFixedGainDivider(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedFixedGainDivider)
    print(io, "SSignedFixedGainDivider(")
    join(io, map(fieldnames(SSignedFixedGainDivider)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

"""
    SSquareRoot

A stochastic bitstream square root operator.
"""
@kwdef mutable struct SSquareRoot
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
    op.counter = max(op.counter + 4 * x.pos - 4 * op.zand, -100)

    # Decide output
    r = rand(op.rng, 0:511)
    z = (op.counter >= r)

    # Update zand
    op.zand = z && pop!(op.buffer)
    push!(op.buffer, z)

    return SBit((z, false))
end
function Base.show(io::IO, x::SSquareRoot)
    print(io, "SSquareRoot(")
    print(io, string(x.counter))
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SSquareRoot)
    print(io, "SSquareRoot(counter = ")
    print(io, string(x.counter))
    print(io, ")")
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
function Base.show(io::IO, x::SMatMultiplier)
    print(io, "SMatMultiplier(")
    show(io, x.counter)
    print(io, ")")
end
function Base.show(io::IO, ::MIME"text/plain", x::SMatMultiplier)
    println(io, "SMatMultiplier(counter = ")
    show(io, MIME("text/plain"), x.counter)
    print(io, "\n)")
end

"""
    SSignedMatMultiplier

A stochastic bitstream matrix multiply operator.
"""
struct SSignedMatMultiplier
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
    pp = op.ppmult(pos.(x), pos.(y))
    pn = op.pnmult(pos.(x), neg.(y))
    np = op.npmult(neg.(x), pos.(y))
    nn = op.nnmult(neg.(x), neg.(y))

    s₁ = map.(op.sub1, pp, pn)
    s₂ = map.(op.sub2, pn, pp)
    s₃ = map.(op.sub3, np, nn)
    s₄ = map.(op.sub4, nn, np)

    z = zip(map.(op.padder, s₁, s₄), map.(op.nadder, s₂, s₃)) |> collect

    return (size(z, 2) == 1) ? SBit.(dropdims(z; dims = 2)) : SBit.(z)
end
Base.show(io::IO, ::SSignedMatMultiplier) = print(io, "SSignedMatMultiplier(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedMatMultiplier)
    print(io, "SSignedMatMultiplier(")
    join(io, map(fieldnames(SSignedMatMultiplier)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

"""
    SL2Normer

A stochastic bitstream L2-norm operator.
"""
@kwdef struct SL2Normer
    dot::SSignedMatMultiplier = SSignedMatMultiplier(1, 1)
    buffer::CircularBuffer{Matrix{SBit}} = CircularBuffer{Matrix{SBit}}(1)
    root::SSquareRoot = SSquareRoot()
end
function (op::SL2Normer)(x::Vector{SBit})
    # get row vector
    dummybit = fill(SBit((false, false)), size(permutedims(x)))
    xt = isempty(op.buffer) ? dummybit : pop!(op.buffer)
    push!(op.buffer, permutedims(x))

    # compute inner product
    xtx = op.dot(xt, x)[1]

    # compute root
    z = op.root(xtx)

    return z
end
Base.show(io::IO, ::SL2Normer) = print(io, "SL2Normer(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SL2Normer)
    print(io, "SL2Normer(")
    join(io, map((:dot, :root)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

@kwdef mutable struct SSignedMaxer
    sub::SSignedSubtractor = SSignedSubtractor()
    counter::Int = 0
end
function (op::SSignedMaxer)(x::SBit, y::SBit)
    z = op.sub(x, y)
    op.counter += pos(z)
    op.counter -= neg(z)

    return (op.counter >= 0) ? x : y
end
Base.show(io::IO, ::SSignedMaxer) = print(io, "SSignedMaxer(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedMaxer)
    print(io, "SSignedMaxer(")
    join(io, map(fieldnames(SSignedMaxer)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end

struct SSignedNMaxer{N}
    maxers::Vector{SSignedMaxer}

    function SSignedNMaxer{N}(maxers::Vector{SSignedMaxer}) where N
        @assert length(maxers) == N - 1 "Incorrect number of `SSignedMaxer`s ($(length(maxers))) for `SSignedNMaxer{$N}`"

        new{N}(maxers)
    end
end
SSignedNMaxer(N) = SSignedNMaxer{N}([SSignedMaxer() for _ in 1:(N - 1)])
function (op::SSignedNMaxer{N})(xs::Vararg{SBit, N}) where N
    z = foldl(zip(op.maxers, Base.tail(xs)); init = first(xs)) do prev, (maxer, curr)
        maxer(prev, curr)
    end

    return z
end
Base.show(io::IO, ::SSignedNMaxer) = print(io, "SSignedNMaxer(...)")
function Base.show(io::IO, ::MIME"text/plain", x::SSignedNMaxer)
    print(io, "SSignedNMaxer(")
    join(io, map(fieldnames(SSignedNMaxer)) do field
        repr(getproperty(x, field))
    end, ", ")
    print(io, ")")
end
