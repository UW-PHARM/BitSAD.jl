const VALID_NET_TYPES = [:logic]
const VALID_NET_CLASSES = [:input, :output, :internal, :constant, :parameter]

_checktype(type) = (type ∈ VALID_NET_TYPES) ||
    throw(ArgumentError("Cannot create net with type $type (use one of $VALID_NET_TYPES)"))
_checkclass(class) = (class ∈ VALID_NET_CLASSES) ||
    throw(ArgumentError("Cannot create net with class $class (use one of $VALID_NET_CLASSES)"))

"""
    Net(; name = "", suffixes = [""], value = missing,
          type = :wire, class = :internal, signed = false,
          bitwidth = 1, size = (1, 1))
    Net(x; kwargs...)

Create a new multi-dimensional SystemVerilog net (for `x`).

# Arguments
- `name::String`: the name of the net (this can be a SystemVerilog constant expression too)
- `suffixes::Vector{String}`: set if this net represents multiple wires with suffixes
                              (e.g. a signed stochastic bitstream has suffixes `_p` and `_m`)
- `value`: the underlying Julia value that this net represents
- `type::Symbol`: one of $VALID_NET_TYPES (a SystemVerilog type)
- `class::Symbol`: one of $VALID_NET_CLASSES
- `signed::Bool`: set true if the net is signed in SystemVerilog
- `bitwidth::Int`: the bit width of each element in the net
- `size::Tuple{Int, Int, ...}`: the size of the net in terms of number of elements

If `x` is specified, then `value = x` and `size = netsize(x)`.
`netsize` is like `Base.size`, but it expands scalars and vectors to 2D sizes (e.g. `(1, 1)`)
If `x` is a `SBitstream` or `AbstractArray{<:SBitstream}`,
then `suffixes = ["_p", "_m"]`.
"""
struct Net{T, S}
    name::String
    suffixes::Vector{String}
    value::T
    type::Symbol
    class::Symbol
    signed::Bool
    bitwidth::Int
    size::S

    function Net(name, suffixes, value::T, type, class, signed, bitwidth, size::S) where {T, S}
        _checktype(type)
        _checkclass(class)

        new{T, S}(name, suffixes, value, type, class, signed, bitwidth, size)
    end
end
Net(; name = "",
      suffixes = [""],
      value = missing,
      type = :logic,
      class = :internal,
      signed = false,
      bitwidth = 1,
      size = (1, 1)) = Net(name, suffixes, value, type, class, signed, bitwidth, size)
Net(x; kwargs...) = Net(; value = x, size = netsize(x), kwargs...)
Net(x::SBitstream; suffixes = ["_p", "_m"], kwargs...) =
    Net(; value = x, size = netsize(x), suffixes = suffixes, kwargs...)
Net(x::AbstractArray{<:SBitstream}; suffixes = ["_p", "_m"], kwargs...) =
    Net(; value = x, size = netsize(x), suffixes = suffixes, kwargs...)

function Base.show(io::IO, n::Net)
    limitedshow(x) = sprint(show, x; context = IOContext(stdout, :compact => true, :limit => true))

    if isconstant(n)
        netname = limitedshow(n.value)
        print(io, "Net{$(n.class), $(n.type)}($(netname)::$(jltypeof(n)))($(join(n.size, "x")))")
    else
        print(io, "Net{$(n.class), $(n.type)}($(n.name)::$(jltypeof(n)))($(join(n.size, "x")))")
    end
end

Base.:(==)(x::Net, y::Net) = name(x) == name(y)
Base.isequal(x::Net, y::Net) = (x == y)
Base.hash(x::Net, h::UInt) = hash(x.name, h)

"""
    name(x::Net)

Return the net name for `x`.
This can be a SystemVerilog constant expression.
"""
name(x::Net) = x.name

"""
    suffixes(x::Net)

Return the suffixes for `x`.
"""
suffixes(x::Net) = x.suffixes

"""
    value(x::Net)

Return the underlying Julia value that `x` represents.
"""
value(x::Net) = x.value

"""
    jltypeof(x::Net)

Return the type of the underlying Julia value that `x` represents.
"""
jltypeof(::Net{T}) where T = T

"""
    bitwidth(x::Net)

Return the bitwidth of elements of `x`
"""
bitwidth(x::Net) = x.bitwidth

"""
    netsize(x)

Return the net size of `x`.
Like `Base.size`, but it expands scalars and vectors to 2D sizes (e.g. `(1, 1)`).
"""
netsize(x) = (1, 1)
netsize(x::AbstractArray) = size(x)
netsize(x::AbstractVector) = (length(x), 1)
function netsize(x::Net)
    isparameter(x) || return x.size

    actual_size = netsize(value(x))
    return ntuple(i -> "$(name(x))_sz_$i", length(actual_size))
end

isinput(x::Net) = (x.class == :input)
isoutput(x::Net) = (x.class == :output)
isinternal(x::Net) = (x.class == :internal)
isconstant(x::Net) = (x.class == :constant)
isparameter(x::Net) = (x.class == :parameter)

issigned(x::Net) = x.signed

const Netlist = Vector{<:Net}

inputs(n::Netlist) = filter(isinput, n)
outputs(n::Netlist) = filter(isoutput, n)

find(n::Netlist, x::Net) = findall(==(name(x)), name.(n))
Base.in(x::Net, n::Netlist) = !isempty(find(n, x))

# function getsize(n::Netlist, x::String)
#     i = find(n, x)
#     isnothing(i) && error("Cannot get size for net $x since it does not exist in netlist.")

#     return n[i].size
# end
# getsize(n::Netlist, x::Vector{String}) = map(λ -> getsize(n, λ), x)

Base.delete!(n::Netlist, x::Net) = deleteat!(n, find(n, x))

function setname(x::Net, name)
    @set! x.name = name

    return x
end
function setname!(n::Netlist, x::Net, name)
    is = find(n, x)
    isempty(is) && error("Cannot name net $x to $name because it does not exist in netlist.")
    for i in is
        n[i] = setname(n[i], name)
    end

    return n
end

function setsuffixes(x::Net, suffixes)
    @set! x.suffixes = suffixes

    return x
end
function setsuffixes!(n::Netlist, x::Net, suffixes)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x suffixes to $suffixes because it does not exist in netlist.")
    for i in is
        n[i] = setsuffixes(n[i], suffixes)
    end

    return n
end

function setvalue(x::Net, value)
    @set! x.value = value

    return x
end
function setvalue!(n::Netlist, x::Net, value)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x value to $value because it does not exist in netlist.")
    for i in is
        n[i] = setvalue(n[i], value)
    end

    return n
end

function setclass(x::Net, class)
    _checkclass(class)
    @set! x.class = class

    return x
end
function setclass!(n::Netlist, x::Net, class)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x as $class because it does not exist in netlist.")
    for i in is
        n[i] = setclass(n[i], class)
    end

    return n
end

function setsigned(x::Net, signed)
    @set! x.signed = signed

    return x
end
function setsigned!(n::Netlist, x::Net, signed)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x as signed = $signed because it does not exist in netlist.")
    for i in is
        n[i] = setsigned(n[i], signed)
    end

    return n
end

function setwidth(x::Net, width)
    @set! x.bitwidth = width

    return x
end
function setwidth!(n::Netlist, x::Net, width)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x bitwidth = $width because it does not exist in netlist.")
    for i in is
        n[i] = setwidth(n[i], width)
    end

    return n
end
