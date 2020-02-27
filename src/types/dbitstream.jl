import Base: +, -, *, /, one, zero

"""
    DBit

A deterministic bit is a single bit representing ±1.

Fields:
- `bit::Bool`: a sample of a bitstream
"""
struct DBit <: AbstractBit
    bit::Bool
end
function DBit(bit::Real)
    if bit != 1 && bit != -1
        error("Cannot create DBit from value $bit (must be ±1).")
    end

    DBit((bit == 1) ? true : false)
end
DBit(bits::VecOrMat{Bool}) = DBit.(bits)

zero(::Type{DBit}) = DBit(false)
zero(::DBit) = zero(DBit)
one(::Type{DBit}) = DBit(true)
one(::DBit) = one(DBit)

"""
    float(b::DBit)

Map `b` to the underlying floating-point value using
``\\{0, 1\\} \\to \\{-1, 1\\}``
"""
float(b::DBit) = b.bit ? 1 : -1

"""
    DBitstream

A deterministic bitstream that looks like a PDM-encoded audio format.

Fields:
- `bits::Queue{DBit}`: the underlying bitstream
"""
struct DBitstream <: AbstractBitstream
    bits::Queue{DBit}
end
DBitstream() = DBitstream(Queue{DBit}())

for op in (:+, :-, :*, :/)
    @eval $(op)(x::DBit, y::DBit) = $(op)(float(x), float(y))
    @eval $(op)(x::DBit, y::Real) = $(op)(float(x), y)
    @eval $(op)(x::Real, y::DBit) = $(op)(x, float(y))
end