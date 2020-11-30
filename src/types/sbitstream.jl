# import Base: +, -, *, /, ÷, sqrt, float
# import LinearAlgebra: norm
using LinearAlgebra

const SBit = @NamedTuple{pos::Bool, neg::Bool}
Base.convert(::Type{SBit}, b::Tuple{Bool, Bool}) = (pos = b[1], neg = b[2])

pos(b::SBit) = b.pos
neg(b::SBit) = b.neg

Base.show(io::IO, b::SBit) = print(io, "($(b.pos), $(b.neg))")
Base.show(io::IO, ::MIME"text/plain", b::SBit) = print(io, "SBit(pos = $(b.pos), neg = $(b.neg))")

"""
    SBitstream

A stochastic bitstream that represents a real (floating-point) number
between [-1, 1].

Fields:
- `bits::Queue{SBit}`: the underlying bitstream
- `value::Float64`: the underlying floating-point number being represented
"""
struct SBitstream{T<:Real} <: AbstractBitstream
    bits::Queue{SBit}
    value::Float64
    id::UInt32

    function SBitstream{T}(bits::Queue{SBit}, value::T, id::UInt32 = _genid()) where {T<:Real}
        if value > 1 || value < -1
            @warn "SBitstream can only be ∈ [-1, 1] (saturation occurring)."
        end

        new{T}(bits, min(max(value, -1), 1), id)
    end
end
SBitstream(value::T) where {T<:Real} = SBitstream{T}(Queue{SBit}(), value)

const SBitstreamLike = Union{<:SBitstream, VecOrMat{<:SBitstream}}

Base.float(s::SBitstream) = s.value
Base.zero(::SBitstream{T}) where T = SBitstream(zero(T))
Base.one(::SBitstream{T}) where T = SBitstream(one(T))

Base.show(io::IO, s::SBitstream) = print(io, "SBitstream($(s.value), $(s.id))")
Base.show(io::IO, ::MIME"text/plain", s::SBitstream{T}) where T =
    print(io, "SBitstream{$T}(value = $(s.value), id = $(s.id))\n    with $(length(s)) bits enqueue.")

include("./soperators.jl")
include("./simulatable.jl")

Base.:(+)(x::SBitstream, y::SBitstream) = SBitstream(x.value + y.value)
@simulatable +(x::SBitstream, y::SBitstream) => SSignedAdder()
Base.:(-)(x::SBitstream, y::SBitstream) = SBitstream(x.value - y.value)
@simulatable -(x::SBitstream, y::SBitstream) => SSignedSubtractor()
Base.:(*)(x::SBitstream, y::SBitstream) = SBitstream(x.value * y.value)
@simulatable *(x::SBitstream, y::SBitstream) => SSignedMultiplier()
function Base.:(/)(x::SBitstream, y::SBitstream)
    if y.value <= 0
        error("SBitstream only supports divisors > 0 (y == $y).")
    end

    SBitstream(x.value / y.value)
end
@simulatable /(x::SBitstream, y::SBitstream) => SSignedDivider()
function Base.:(÷)(x::SBitstream, y::Real)
    if y < 1
        error("SBitstream only supports fixed-gain divisors >= 1 (y == $y).")
    end

    SBitstream(x.value / y)
end
@simulatable ÷(x::SBitstream, y::Real) => SSignedFixedGainDivider()
Base.sqrt(x::SBitstream) = SBitstream(sqrt(x.value))
@simulatable sqrt(x::SBitstream) => SSquareRoot()
decorrelate(x::SBitstream) = SBitstream(x.value)
@simulatable decorrelate(x::SBitstream) => SSignedDecorrelator()
Base.:(*)(x::VecOrMat{<:SBitstream}, y::VecOrMat{<:SBitstream}) = SBitstream.(float.(x) * float.(y))
@simulatable *(x::VecOrMat{<:SBitstream}, y::VecOrMat{<:SBitstream}) => SSignedMatMultiplier(size(x, 1), size(y, 2))
LinearAlgebra.norm(x::Vector{<:SBitstream}) = SBitstream(norm(float.(x)))
@simulatable norm(x::Vector{<:SBitstream}) => SL2Normer()

"""
    generate(s::SBitstream, T::Integer = 1)
    generate!(s::SBitstream, T::Integer = 1)

Generate `T` samples of the bitstream, `s`.
Add them to the queue for `generate!`, otherwise return the vector of bits.
"""
function generate(s::SBitstream, T::Integer = 1)
    bits = rand(T) .< abs(s.value)
    sbits = map(b -> (s.value >= 0) ? (pos = b, neg = false) : (pos = false, neg = b), bits)

    return sbits
end
generate!(s::SBitstream, T::Integer = 1) = push!(s, generate(s, T))

pop!(s::SBitstream) = isempty(s.bits) ? generate(s)[1] : dequeue!(s.bits)

"""
    estimate!(buffer::AbstractVector, b::SBit)
    estimate!(buffer::AbstractVector, b::VecOrMat{SBit})
    estimate!(buffer::AbstractVector)

Push `b` into the `buffer` and return the current estimate.
"""
function estimate!(buffer::AbstractVector, s::SBitstream)
    b = observe(s)
    push!(buffer, pos(b) - neg(b))

    return sum(buffer) / length(buffer)
end
function estimate!(buffer::AbstractVector, s::VecOrMat{<:SBitstream})
    bs = observe(s)
    push!(buffer, pos.(bs) - neg.(bs))

    return sum(buffer) / length(buffer)
end
estimate!(buffer::AbstractVector) = sum(buffer) / length(buffer)
estimate!(s::SBitstream) = mapreduce(x -> x.pos - x.neg, +, s.bits) / length(s)