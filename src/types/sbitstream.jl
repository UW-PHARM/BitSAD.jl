import Base: +, -, *, /, ÷, sqrt
import LinearAlgebra: norm

_genid() = uuid4()
_indexid(id::UUID, idx::Integer) = uuid5(id, "[$idx]")
_getidstr(x::AbstractBit) = x.id.value
_getidstr(x::VecOrMat{<:AbstractBit}) = string(map(λ -> λ.id.value, x)...)
_getidstr(x) = x

"""
    SBit

A stochastic bit is a pair of unipolar bits (positive and negative channels).

Fields:
- `bit::Tuple{Bool, Bool}`: a sample of a bitstream
- `value::Float64`: the underlying floating-point number being represented
- `id::UUID`: a unique identifier for all samples of this bitstream
"""
struct SBit <: AbstractBit
    bit::Tuple{Bool, Bool}
    value::Float64
    id::UUID

    function SBit(bit::Tuple{Bool, Bool}, value::Float64, id::UUID)
        if value > 1 || value < -1
            @warn "SBitstream can only be ∈ [-1, 1] (saturation occurring)."
        end

        new(bit, min(max(value, -1), 1), id)
    end
end
function SBit(bits::VecOrMat{Tuple{Bool, Bool}}, values::VecOrMat{Float64}, id::UUID)
    arr = similar(bits, SBit)
    for (i, bit) in enumerate(bits)
        arr[i] = SBit(bit, values[i], _indexid(id, i))
    end

    return arr
end


"""
    pos(b::SBit)

Return the positive channel bit of a stochastic bit.
"""
pos(b::SBit) = b.bit[1]

"""
    neg(b::SBit)

Return the negative channel bit of a stochastic bit.
"""
neg(b::SBit) = b.bit[2]

include("./soperators.jl")
include("./simulatable.jl")

@simulatable(SSignedAdder,      +(x::SBit, y::SBit) = x.value + y.value)
@simulatable(SSignedSubtractor, -(x::SBit, y::SBit) = x.value - y.value)
@simulatable(SSignedMultiplier, *(x::SBit, y::SBit) = x.value * y.value)
@simulatable(SSignedDivider,
function /(x::SBit, y::SBit)
    if y.value <= 0
        error("SBit only supports divisors > 0 (y == $y).")
    end

    x.value / y.value
end)
@simulatable(SFixedGainDivider,
function ÷(x::SBit, y::Real)
    if y < 1
        error("SBit only supports fixed-gain divisors >= 1 (y == $y).")
    end

    x.value / y
end)
@simulatable(SSquareRoot,         sqrt(x::SBit) = sqrt(x.value))
@simulatable(SSignedDecorrelator, decorrelate(x::SBit) = x.value)
@simulatable(SSignedMatMultiplier,
    *(x::VecOrMat{SBit}, y::VecOrMat{SBit}) = map(z -> z.value, x) * map(z -> z.value, y), (size(x, 1), size(y, 2)))
@simulatable(SL2Normer,           norm(x::Vector{SBit}) = norm(map(z -> z.value, x)))

"""
    SBitstream

A stochastic bitstream that represents a real (floating-point) number
between [-1, 1].

Fields:
- `bits::Queue{SBit}`: the underlying bitstream
- `value::Float64`: the underlying floating-point number being represented
- `id::UUID`: a unique identifier for this bitstream (set automatically)
"""
struct SBitstream <: AbstractBitstream
    bits::Queue{SBit}
    value::Float64
    id::UUID

    function SBitstream(bits::Queue{SBit}, value::Float64, id::UUID = _genid())
        if value > 1 || value < -1
            @warn "SBitstream can only be ∈ [-1, 1] (saturation occurring)."
        end

        new(bits, min(max(value, -1), 1), id)
    end
end
SBitstream(value::Real, id::UUID = _genid()) = SBitstream(Queue{SBit}(), float(value), id)
function SBitstream(values::VecOrMat{Float64}, id::UUID = _genid())
    arr = similar(values, SBitstream)
    for (i, value) in enumerate(values)
        arr[i] = SBitstream(value, _indexid(id, i))
    end

    return arr
end

"""
    generate(s::SBitstream, T::Integer = 1)
    generate!(s::SBitstream, T::Integer = 1)

Generate `T` samples of the bitstream.
Add them to its queue for `generate!`.
"""
function generate(s::SBitstream, T::Integer = 1)
    r = rand(T)
    bits = (s.value >= 0) ? zip(r .< abs(s.value), fill(false, T)) :
                            zip(fill(false, T), r .< abs(s.value))
    sbits = map(x -> SBit(x, s.value, s.id), bits)

    return sbits
end
generate!(s::SBitstream, T::Integer = 1) = push!(s, generate(s, T))

pop!(s::SBitstream) = isempty(s.bits) ? generate(s)[1] : dequeue!(s.bits)

for op in (:+, :-, :*, :/)
    @eval function $(op)(x::SBitstream, y::SBitstream)
        zbit = $(op)(pop!(x), pop!(y))
        z = SBitstream(zbit.value, zbit.id)
        push!(z, zbit)

        return z
    end
end
for op in (:sqrt, :decorrelate)
    @eval function $(op)(x::SBitstream)
        zbit = $(op)(pop!(x))
        z = SBitstream(zbit.value, zbit.id)
        push!(z, zbit)

        return z
    end
end
function ÷(x::SBitstream, y::Real)
    zbit = pop!(x) ÷ y
    z = SBitstream(zbit.value, zbit.id)
    push!(z, zbit)

    return z
end
function *(x::VecOrMat{SBitstream}, y::VecOrMat{SBitstream})
    zbit = pop!.(x) * pop!.(y)
    z = map(λ -> SBitstream(λ.value, λ.id), zbit)
    push!.(z, zbit)

    return z
end
function norm(x::Vector{SBitstream})
    zbit = norm(pop!.(x))
    z = SBitstream(zbit.value, zbit.id)
    push!(z, zbit)

    return z
end