const SBit = @NamedTuple{pos::Bool, neg::Bool}
Base.convert(::Type{SBit}, b::Tuple{Bool, Bool}) = (pos = b[1], neg = b[2])
Base.promote_rule(::Type{SBit}, ::Type{Tuple{Bool, Bool}}) = SBit

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
    value::T

    function SBitstream{T}(bits::Queue{SBit}, value::T) where {T<:Real}
        if value > 1 || value < -1
            @warn "SBitstream can only be ∈ [-1, 1] (saturation occurring)."
        end

        new{T}(bits, min(max(value, -1), 1))
    end
end
SBitstream(value::T) where {T<:Real} = SBitstream{T}(Queue{SBit}(), value)
SBitstream{T}(value::Real) where {T<:Real} = SBitstream(convert(T, value))
Base.convert(::Type{SBitstream{T}}, s::SBitstream) where {T<:Real} =
    SBitstream{T}(s.bits, convert(T, s.value))

const SBitstreamLike = Union{<:SBitstream, AbstractArray{<:SBitstream}}

Base.float(s::SBitstream) = s.value
Base.zero(::SBitstream{T}) where T = SBitstream(zero(T))
Base.one(::SBitstream{T}) where T = SBitstream(one(T))

Base.show(io::IO, s::SBitstream) = print(io, "SBitstream($(s.value))")
Base.show(io::IO, ::MIME"text/plain", s::SBitstream{T}) where T =
    print(io, "SBitstream{$T}(value = $(s.value))\n    with $(length(s)) bits enqueue.")

include("./soperators.jl")

Base.:(+)(x::SBitstream, y::SBitstream) = SBitstream(x.value + y.value)
is_trace_primitive(::typeof(+), ::SBitstream, ::SBitstream...) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(+),
                   ::SBitstreamLike,
                   ::SBitstreamLike...) = true
getsimulator(::typeof(+), x::SBitstream, y::SBitstream) = SSignedAdder()
getsimulator(::typeof(Base.broadcasted), ::typeof(+), x::SBitstreamLike, y::SBitstreamLike) =
    getsimulator.(+, x, y)

Base.:(-)(x::SBitstream, y::SBitstream) = SBitstream(x.value - y.value)
is_trace_primitive(::typeof(-), ::SBitstreamLike, ::SBitstreamLike...) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(-),
                   ::SBitstreamLike,
                   ::SBitstreamLike...) = true
getsimulator(::typeof(+), x::SBitstreamLike, y::SBitstream) = SSignedSubtractor()
getsimulator(::typeof(Base.broadcasted), ::typeof(-), x::SBitstreamLike, y::SBitstreamLike) =
    getsimulator.(-, x, y)

Base.:(*)(x::SBitstream, y::SBitstream) = SBitstream(x.value * y.value)
is_trace_primitive(::typeof(*), ::SBitstreamLike, ::SBitstreamLike...) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(*),
                   ::SBitstreamLike,
                   ::SBitstreamLike...) = true
getsimulator(::typeof(*), x::SBitstreamLike, y::SBitstream) = SSignedMultiplier()
getsimulator(::typeof(Base.broadcasted), ::typeof(*), x::SBitstreamLike, y::SBitstreamLike) =
    getsimulator.(*, x, y)

function Base.:(/)(x::SBitstream, y::SBitstream)
    if y.value <= 0
        error("SBitstream only supports divisors > 0 (y == $y).")
    end

    SBitstream(x.value / y.value)
end
is_trace_primitive(::typeof(/), ::SBitstreamLike, ::SBitstreamLike...) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(/),
                   ::SBitstreamLike,
                   ::SBitstreamLike...) = true
getsimulator(::typeof(/), x::SBitstreamLike, y::SBitstream) = SSignedDivider()
getsimulator(::typeof(Base.broadcasted), ::typeof(/), x::SBitstreamLike, y::SBitstreamLike) =
    getsimulator.(/, x, y)

function Base.:(÷)(x::SBitstream, y::Real)
    if y < 1
        error("SBitstream only supports fixed-gain divisors >= 1 (y == $y).")
    end

    SBitstream(x.value / y)
end
is_trace_primitive(::typeof(÷), ::SBitstreamLike, ::Real) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(÷),
                   ::SBitstreamLike,
                   ::Real) = true
getsimulator(::typeof(÷), x::SBitstreamLike, y::Real) = SSignedFixedGainDivider()

Base.sqrt(x::SBitstream) = SBitstream(sqrt(x.value))
is_trace_primitive(::typeof(sqrt), x::SBitstreamLike) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(sqrt),
                   ::SBitstreamLike) = true
getsimulator(::typeof(sqrt), x::SBitstreamLike) = SSquareRoot()

decorrelate(x::SBitstream) = SBitstream(x.value)
is_trace_primitive(::typeof(decorrelate), x::SBitstreamLike) = true
is_trace_primitive(::typeof(Base.broadcasted),
                   ::typeof(decorrelate),
                   ::SBitstreamLike) = true
getsimulator(::typeof(decorrelate), x::SBitstreamLike) = SSignedDecorrelator()

Base.:(*)(x::AbstractVecOrMat{<:SBitstream}, y::AbstractVecOrMat{<:SBitstream}) =
    SBitstream.(float.(x) * float.(y))
is_trace_primitive(::typeof(*),
                   ::AbstractVecOrMat{<:SBitstream},
                   ::AbstractVecOrMat{<:SBitstream}) = true
getsimulator(::typeof(*), x::AbstractVecOrMat{<:SBitstream}, y::AbstractVecOrMat{<:SBitstream}) =
    SSignedMatMultiplier(size(x, 1), size(y, 2))

LinearAlgebra.norm(x::AbstractVector{<:SBitstream}) = SBitstream(norm(float.(x)))
is_trace_primitive(::typeof(LinearAlgebra.norm), ::AbstractVector{<:SBitstream}) = true
getsimulator(::typeof(LinearAlgebra.norm), x::AbstractVector{<:SBitstream}) = SL2Normer()

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

Base.pop!(s::SBitstream) = isempty(s.bits) ? generate(s)[1] : dequeue!(s.bits)

"""
    estimate(buffer::AbstractVector)
    estimate(s::SBitstream)

Get the empirical mean of the bits in `buffer`/`s`
"""
estimate(buffer::AbstractVector) = sum(buffer) / length(buffer)
estimate(s::SBitstream) = mapreduce(x -> x.pos - x.neg, +, s.bits) / length(s)

"""
    estimate!(buffer::AbstractVector, b::SBit)
    estimate!(buffer::AbstractVector, b::VecOrMat{SBit})
    estimate(buffer::AbstractVector)
    estimate(s::SBitstream)

Push `b` into the `buffer` and return the current [`estimate`](#).
"""
function estimate!(buffer::AbstractVector, s::SBitstream)
    b = observe(s)
    push!(buffer, pos(b) - neg(b))

    return estimate(buffer)
end
function estimate!(buffer::AbstractVector, s::VecOrMat{<:SBitstream})
    bs = observe(s)
    push!(buffer, pos.(bs) - neg.(bs))

    return estimate(buffer)
end
