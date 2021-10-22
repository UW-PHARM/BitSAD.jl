_checktype(type) = (type != :reg && type != :wire) &&
    error("Cannot create net with type $type (use :reg or :wire)")
_checkclass(class) = (class != :input &&
                      class != :output &&
                      class != :internal &&
                      class != :constant &&
                      class != :parameter) &&
    error("Cannot create net with class $class (use :input, :output, :internal, :constant, or :parameter)")

struct Net
    name
    value
    type::Symbol
    class::Symbol
    signed::Bool
    bitwidth::Int
    size

    function Net(name, value, type, class, signed, bitwidth, size)
        _checktype(type)
        _checkclass(class)

        new(name, value, type, class, signed, bitwidth, size)
    end
end
Net(; name = "",
      value = missing,
      type = :wire,
      class = :internal,
      signed = false,
      bitwidth = 1,
      size = (1, 1)) = Net(name, value, type, class, signed, bitwidth, size)
Net(x; kwargs...) = Net(; value = x, size = netsize(x), kwargs...)

function Base.show(io::IO, n::Net)
    limitedshow(x) = sprint(show, x; context = IOContext(stdout, :compact => true, :limit => true))

    if isconstant(n)
        netname = limitedshow(n.value)
        print(io, "Net{$(n.class), $(n.type)}($(netname)::$(jltypeof(n)))($(n.size[1])x$(n.size[2]))")
    else
        print(io, "Net{$(n.class), $(n.type)}($(n.name)::$(jltypeof(n)))($(n.size[1])x$(n.size[2]))")
    end
end

Base.:(==)(x::Net, y::Net) = name(x) == name(y)
Base.isequal(x::Net, y::Net) = (x == y)
Base.hash(x::Net, h::UInt) = hash(x.name, h)

name(x::Net) = x.name

value(x::Net) = x.value

jltypeof(x::Net) = typeof(value(x))

bitwidth(x::Net) = x.bitwidth

netsize(x) = (1, 1)
netsize(x::AbstractArray) = size(x)
netsize(x::AbstractVector) = (length(x), 1)
function netsize(x::Net)
    isparameter(x) || return x.size

    actual_size = netsize(value(x))
    return ntuple(i -> "$(name(x))_sz_$i", length(actual_size))
end

isreg(x::Net) = (x.type == :reg)
iswire(x::Net) = !isreg(x)

isinput(x::Net) = (x.class == :input)
isoutput(x::Net) = (x.class == :output)
isinternal(x::Net) = (x.class == :internal)
isconstant(x::Net) = (x.class == :constant)
isparameter(x::Net) = (x.class == :parameter)

issigned(x::Net) = x.signed

const Netlist = Vector{Net}

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

function setreg(x::Net)
    @set! x.type = :reg

    return x
end
function setreg!(n::Netlist, x::Net)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x as register because it does not exist in netlist.")
    for i in is
        n[i] = setreg(n[i])
    end

    return n
end

function setwire(x::Net)
    @set! x.type = :wire

    return x
end
function setwire!(n::Netlist, x::Net)
    is = find(n, x)
    isempty(is) && error("Cannot set net $x as wire because it does not exist in netlist.")
    for i in is
        n[i] = setwire(n[i])
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
