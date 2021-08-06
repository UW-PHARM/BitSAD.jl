"""
    AbstractBitstream

Inherit from this type to create a custom bitstream type.

Expected fields:
- `bits::Queue{AbstractBit}`: the underlying bitstream
"""
abstract type AbstractBitstream <: Number end

"""
    push!(s::AbstractBitstream, b)

Push a bit(s) `b` onto bitstream `s`.

Fields:
- `s::AbstractBitstream`: the bitstream object
- `b`: the bit(s) to push onto the stream
"""
Base.push!(s::AbstractBitstream, b) = enqueue!(s.bits, b)
function Base.push!(s::AbstractBitstream, bs::Vector)
    for b in bs
        push!(s, b)
    end
end
Base.push!(s::VecOrMat{<:AbstractBitstream}, bs::VecOrMat) = push!.(s, bs)

"""
    pop!(s::AbstractBitstream)

Pop a bit from bitstream `s`.

Fields:
- `s::AbstractBitstream`: the bitstream object
"""
Base.pop!(s::AbstractBitstream) = dequeue!(s.bits)
Base.pop!(s::VecOrMat{<:AbstractBitstream}) = pop!.(s)

"""
    observe(s::AbstractBitstream)

Examine the most recent bit added to the stream without removing it.

Fields:
- `s::AbstractBitstream`: the bitstream object
"""
observe(s::AbstractBitstream) = last(s.bits)
observe(s::VecOrMat{<:AbstractBitstream}) = observe.(s)

"""
    length(s::AbstractBitstream)

Return the number of bits in `s`.
"""
Base.length(s::AbstractBitstream) = length(s.bits)

Base.iterate(s::AbstractBitstream, state...) = iterate(s.bits, state...)

Base.eltype(s::AbstractBitstream) = eltype(s.bits)

Base.getindex(s::AbstractBitstream, i::Integer) = Iterators.take(s.bits, i) |> collect |> last
Base.firstindex(s::AbstractBitstream) = 1
Base.lastindex(s::AbstractBitstream) = length(s)
