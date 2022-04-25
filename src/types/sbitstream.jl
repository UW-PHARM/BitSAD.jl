const SBit = @NamedTuple{pos::Bool, neg::Bool}
Base.convert(::Type{SBit}, b::Tuple{Bool, Bool}) = (pos = b[1], neg = b[2])
Base.promote_rule(::Type{SBit}, ::Type{Tuple{Bool, Bool}}) = SBit

pos(b::SBit) = b.pos
neg(b::SBit) = b.neg

Base.zero(::Type{SBit}) = SBit((false, false))
Base.one(::Type{SBit}) = SBit((true, false))
SBit(pos::Bool, neg::Bool) = SBit((pos, neg))
SBit(value::Number) = isone(value) ? one(SBit) :
                      iszero(value) ? zero(SBit) :
                      error("Cannot create an SBit($value). Use pop!(SBitstream($value)) instead.")

Base.show(io::IO, b::SBit) = print(io, "($(b.pos), $(b.neg))")
Base.show(io::IO, ::MIME"text/plain", b::SBit) = print(io, "SBit(pos = $(b.pos), neg = $(b.neg))")

"""
    SBitstream(value::Real)
    SBitstream{T<:Real}(value)

A stochastic bitstream that represents a real (floating-point) number
between [-1, 1].

!!! tip
    You can turn of saturation warnings by calling
    `BitSAD.set_saturation_verbosity(:none)`.
    Turn them back on by calling
    `BitSAD.set_saturation_verbosity(:full)`.

Fields:
- `bits::Vector{SBit}`: the underlying bitstream
- `value::T`: the underlying floating-point number being represented
"""
struct SBitstream{T<:Real} <: Number
    bits::Vector{SBit}
    value::T

    function SBitstream{T}(bits::Vector{SBit}, value::T) where {T<:Real}
        if value > 1 || value < -1
            if verbosity[] == :full
                @warn "SBitstream can only be ∈ [-1, 1] (saturation occurring)."
            end
        end

        new{T}(bits, min(max(value, -1), 1))
    end
end
SBitstream(value::T) where {T<:Real} = SBitstream{T}(Vector{SBit}(), value)
SBitstream{T}(value::Real) where {T<:Real} = SBitstream(convert(T, value))
Base.convert(::Type{SBitstream{T}}, s::SBitstream) where {T<:Real} =
    SBitstream{T}(s.bits, convert(T, s.value))

const SBitstreamLike = Union{<:SBitstream, AbstractArray{<:SBitstream}}

bits(s::SBitstream) = s.bits

Base.float(s::SBitstream) = s.value
Base.zero(::SBitstream{T}) where T = SBitstream(zero(T))
Base.one(::SBitstream{T}) where T = SBitstream(one(T))

Base.promote_rule(::Type{SBitstream{T}}, ::Type{S}) where {T, S<:Number} =
    SBitstream{promote_type(T, S)}

Base.typemin(::Type{T}) where {T<:SBitstream} = zero(T)
Base.typemax(::Type{T}) where {T<:SBitstream} = one(T)

Base.isinf(::SBitstream) = false
Base.isnan(::SBitstream) = false

Base.isless(x::SBitstream, y::SBitstream) = Base.isless(float(x), float(y))
Base.:(==)(x::SBitstream, y::SBitstream) = (float(x) == float(y))
Base.hash(x::SBitstream, h::UInt) = hash(float(x), h)

Base.show(io::IO, s::SBitstream) = print(io, "SBitstream($(s.value))")
Base.show(io::IO, ::MIME"text/plain", s::SBitstream{T}) where T =
    print(io, "SBitstream{$T}(value = $(s.value))\n    with $(length(s)) bits.")

include("./soperators.jl")

Base.:(+)(x::SBitstream, y::SBitstream) = SBitstream(float(x) + float(y))

Base.:(-)(x::SBitstream, y::SBitstream) = SBitstream(float(x) - float(y))

Base.:(*)(x::SBitstream, y::SBitstream) = SBitstream(float(x) * float(y))

function Base.:(/)(x::SBitstream, y::SBitstream)
    if float(y) <= 0
        error("SBitstream only supports divisors > 0 (y == $y).")
    end

    SBitstream(float(x) / y.value)
end

for (op, sim) in ((:+, :SSignedAdder),
                  (:-, :SSignedSubtractor),
                  (:*, :SSignedMultiplier),
                  (:/, :SSignedDivider))
    @eval begin
        is_trace_primitive(::Type{typeof($op)},
                           ::Type{<:SBitstream},
                           ::Type{<:SBitstream}) = true
        is_trace_primitive(::Type{typeof(Base.broadcasted)},
                           ::Type{typeof($op)},
                           ::Type{<:SBitstreamLike},
                           ::Type{<:SBitstreamLike}) = true
        getsimulator(::typeof($op), x::SBitstream, y::SBitstream) = $(sim)()
        getsimulator(::typeof(Base.broadcasted),
                     ::typeof($op),
                     x::SBitstreamLike,
                     y::SBitstreamLike) = getsimulator.($op, x, y)
    end
end

Base.:(*)(x::SBitstreamLike, y::SBitstreamLike) = x .* y
is_trace_primitive(::Type{typeof(*)},
                   ::Type{<:SBitstreamLike},
                   ::Type{<:SBitstreamLike}) = true
getsimulator(::typeof(*), x::SBitstreamLike, y::SBitstreamLike) = getsimulator.(*, x, y)

function Base.:(÷)(x::SBitstream, y::Real)
    if y < 1
        error("SBitstream only supports fixed-gain divisors >= 1 (y == $y).")
    end

    SBitstream(float(x) / y)
end
is_trace_primitive(::Type{typeof(÷)}, ::Type{<:SBitstreamLike}, ::Type{<:Real}) = true
is_trace_primitive(::Type{typeof(Base.broadcasted)},
                   ::Type{typeof(÷)},
                   ::Type{<:SBitstreamLike},
                   ::Type{<:Real}) = true
getsimulator(::typeof(÷), x::SBitstream, y::Real) = SSignedFixedGainDivider()
getsimulator(::typeof(Base.broadcasted), ::typeof(÷), x::SBitstreamLike, y::Real) =
    getsimulator.(÷, x, y)

Base.sqrt(x::SBitstream) = SBitstream(sqrt(float(x)))
is_trace_primitive(::Type{typeof(sqrt)}, ::Type{<:SBitstreamLike}) = true
is_trace_primitive(::Type{typeof(Base.broadcasted)},
                   ::Type{typeof(sqrt)},
                   ::Type{<:SBitstreamLike}) = true
getsimulator(::typeof(sqrt), x::SBitstream) = SSquareRoot()
getsimulator(::typeof(Base.broadcasted), ::typeof(sqrt), x::SBitstream) = getsimulator.(sqrt, x)

decorrelate(x::Number) = x
decorrelate(x::SBitstream) = SBitstream(float(x))
is_trace_primitive(::Type{typeof(decorrelate)}, ::Type{<:SBitstream}) = true
is_trace_primitive(::Type{typeof(Base.broadcasted)},
                   ::Type{typeof(decorrelate)},
                   ::Type{<:SBitstreamLike}) = true
getsimulator(::typeof(decorrelate), x::SBitstream) = SSignedDecorrelator()
getsimulator(::typeof(Base.broadcasted), ::typeof(decorrelate), x::SBitstreamLike) =
    getsimulator.(decorrelate, x)

Base.:(*)(x::AbstractVecOrMat{<:SBitstream}, y::AbstractVecOrMat{<:SBitstream}) =
    SBitstream.(float.(x) * float.(y))
Base.:(*)(x::LinearAlgebra.Transpose{<:SBitstream, <:AbstractVector}, y::AbstractMatrix{<:SBitstream}) =
    SBitstream.(float.(x) * float.(y))
is_trace_primitive(::Type{typeof(*)},
                   ::Type{<:AbstractVecOrMat{<:SBitstream}},
                   ::Type{<:AbstractVecOrMat{<:SBitstream}}) = true
getsimulator(::typeof(*), x::AbstractVecOrMat{<:SBitstream}, y::AbstractVecOrMat{<:SBitstream}) =
    SSignedMatMultiplier(size(x, 1), size(y, 2))

LinearAlgebra.norm(x::AbstractVector{<:SBitstream}) = SBitstream(norm(float.(x)))
is_trace_primitive(::Type{typeof(LinearAlgebra.norm)}, ::Type{<:AbstractVector{<:SBitstream}}) = true
getsimulator(::typeof(LinearAlgebra.norm), x::AbstractVector{<:SBitstream}) = SL2Normer()

Base.max(x::SBitstream, y::SBitstream, zs::SBitstream...) = SBitstream(max(float(x), float(y), float.(zs)...))
is_trace_primitive(::Type{typeof(max)}, ::Type{<:SBitstream}, ::Type{<:SBitstream}, ::Type{<:SBitstream}...) = true
is_trace_primitive(::Type{typeof(Base.broadcasted)},
                   ::Type{typeof(max)},
                   ::Type{<:SBitstreamLike},
                   ::Type{<:SBitstreamLike},
                   ::Type{<:SBitstreamLike}...) = true
getsimulator(::typeof(max), x::SBitstream, y::SBitstream, zs::SBitstream...) = SSignedNMaxer(length(zs) + 2)
getsimulator(::typeof(max),
             x::SBitstreamLike,
             y::SBitstreamLike,
             zs::SBitstreamLike...) = getsimulator.(max, x, y, zs...)

average(x, y, zs...) = sum([x, y, zs...]) / (length(zs) + 2)
average(x::SBitstream, y::SBitstream, zs::SBitstream...) = SBitstream(average(float(x), float(y), float.(zs)...))
is_trace_primitive(::Type{typeof(average)}, ::Type{<:SBitstream}, ::Type{<:SBitstream}, ::Type{<:SBitstream}...) = true
is_trace_primitive(::Type{typeof(Base.broadcasted)},
                   ::Type{typeof(average)},
                   ::Type{<:SBitstreamLike},
                   ::Type{<:SBitstreamLike},
                   ::Type{<:SBitstreamLike}...) = true
getsimulator(::typeof(average), x::SBitstream, y::SBitstream, zs::SBitstream...) = SSignedAverager{length(zs) + 2}()
getsimulator(::typeof(average),
             x::SBitstreamLike,
             y::SBitstreamLike,
             zs::SBitstreamLike...) = getsimulator.(average, x, y, zs...)

"""
    generate(s::SBitstream, T::Integer = 1)
    generate!(s::SBitstream, T::Integer = 1)

Generate `T` samples of the bitstream, `s`.
Add them to the queue for `generate!`, otherwise return the vector of bits.
"""
function generate(s::SBitstream{FT}, T::Integer = 1) where FT
    bits = rand(FT, T) .< abs(s.value)
    sbits = map(b -> (s.value >= 0) ? (pos = b, neg = false) : (pos = false, neg = b), bits)

    return sbits
end
function _generate_array(s::AbstractArray{<:SBitstream{FT}}, T::Integer = 1) where FT
    values = float.(s)
    bits = rand(FT, size(s)..., T) .< abs.(values)
    isneg = values .>= 0
    sbits = SBit.(bits .* .!(isneg), bits .* isneg)

    return sbits
end
Base.broadcasted(::typeof(generate), s::AbstractArray{<:SBitstream}, args...) =
    _generate_array(s, args...)
generate!(s::SBitstream, T::Integer = 1) = append!(s, generate(s, T))
Base.broadcasted(::typeof(generate!), s::AbstractArray{<:SBitstream}, args...) =
    append!.(s, _generate_array(s, args...))

Base.length(s::SBitstream) = length(bits(s))

Base.iterate(s::SBitstream, state...) = iterate(bits(s), state...)

Base.eltype(s::SBitstream) = eltype(bits(s))

Base.getindex(s::SBitstream, i::Integer) = s.bits[i]
Base.firstindex(s::SBitstream) = 1
Base.lastindex(s::SBitstream) = length(s)

Base.push!(s::SBitstream, b) = push!(s.bits, b)
Base.append!(s::SBitstream, bits) = foreach(Base.Fix1(push!, s), bits)
Base.pop!(s::SBitstream) = isempty(s.bits) ? generate(s)[1] : popfirst!(s.bits)
observe(s::SBitstream) = last(s.bits)

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
    bs = observe.(s)
    push!(buffer, pos.(bs) - neg.(bs))

    return estimate(buffer)
end
