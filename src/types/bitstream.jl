"""
    AbstractBitstream

Inherit from this type to create a custom bitstream type.
"""
abstract type AbstractBitstream <: Number end

"""
    push!(s::AbstractBitstream, b)

Push a bit(s) `b` onto bitstream `s`.

Fields:
- `s::AbstractBitstream`: the bitstream object
- `b`: the bit(s) to push onto the stream
"""
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
Base.pop!(s::VecOrMat{<:AbstractBitstream}) = pop!.(s)

"""
    observe(s::AbstractBitstream)

Examine the most recent bit added to the stream without removing it.

Fields:
- `s::AbstractBitstream`: the bitstream object
"""
observe(s::VecOrMat{<:AbstractBitstream}) = observe.(s)

"""
    length(s::AbstractBitstream)

Return the number of bits in `s`.
"""
Base.length(s::AbstractBitstream) = length(bits(s))

Base.iterate(s::AbstractBitstream, state...) = iterate(bits(s), state...)

Base.eltype(s::AbstractBitstream) = eltype(bits(s))

Base.getindex(s::AbstractBitstream, i::Integer) = Iterators.take(bits(s), i) |> collect |> last
Base.firstindex(s::AbstractBitstream) = 1
Base.lastindex(s::AbstractBitstream) = length(s)
