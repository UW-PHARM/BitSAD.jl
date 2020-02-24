import Base: push!, pop!, length

"""
    AbstractBit

Inherit from this type to create a custom bit type.
"""
abstract type AbstractBit <: Number end

"""
    AbstractBitstream

Inherit from this type to create a custom bitstream type.

Expected fields:
- `bits::Queue{AbstractBit}`: the underlying bitstream
"""
abstract type AbstractBitstream end

"""
    push!(s::AbstractBitstream, b)

Push a bit(s) `b` onto bitstream `s`.

Fields:
- `s::AbstractBitstream`: the bitstream object
- `b`: the bit(s) to push onto the stream
"""
push!(s::AbstractBitstream, b::AbstractBit) = enqueue!(s.bits, b)
function push!(s::AbstractBitstream, bs::Vector{<:AbstractBit})
    for b in bs
        push!(s, b)
    end
end

"""
    pop!(s::AbstractBitstream)

Pop a bit from bitstream `s`.

Fields:
- `s::AbstractBitstream`: the bitstream object
"""
pop!(s::AbstractBitstream) = dequeue!(s.bits)

"""
    observe(s::AbstractBitstream)

Examine the most recent bit added to the stream without removing it.

Fields:
- `s::AbstractBitstream`: the bitstream object
"""
observe(s::AbstractBitstream) = last(s.bits)

"""
    length(s::AbstractBitstream)

Return the number of bits in `s`.
"""
length(s::AbstractBitstream) = length(s.bits)