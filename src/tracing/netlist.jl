_checktype(type) = (type != :reg && type != :wire) &&
    error("Cannot create net with type $type (use :reg or :wire)")
_checkclass(class) = (class != :input &&
                      class != :output &&
                      class != :internal &&
                      class != :constant &&
                      class != :parameter) &&
    error("Cannot create net with class $class (use :input, :output, :internal, :constant, or :parameter)")
_checksize(size) = any(size .< 1) &&
    error("Cannot create net with size $size (size[i] must be >= 1)")

@kwdef struct Net
    name::String = ""
    jltype::Type = Any
    type::Symbol = :wire
    class::Symbol = :internal
    signed::Bool = false
    size::Tuple{Int, Int}

    function Net(name, jltype, type, class, signed, size)
        _checktype(type)
        _checkclass(class)
        _checksize(size)

        new(name, jltype, type, class, signed, size)
    end
end
Net(x; kwargs...) = Net(; jltype = typeof(x), size = netsize(x), kwargs...)

Base.show(io::IO, n::Net) =
    print(io, "Net{$(n.class), $(n.type)}($(n.name)::$(n.jltype))($(n.size[1])x$(n.size[2]))")

netsize(x) = (1, 1)
netsize(x::AbstractArray) = size(x)
netsize(x::AbstractVector) = (length(x), 1)
netsize(x::Net) = x.size

name(x::Net) = x.name

jltypeof(x::Net) = x.jltype

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

find(n::Netlist, x::Net) = findfirst(λ -> λ.name == name(x), n)
Base.in(n::Netlist, x::Net) = !isnothing(find(n, x))

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
    i = find(n, x)
    isnothing(i) && error("Cannot name net $x to $name because it does not exist in netlist.")
    n[i] = setname(n[i], name)

    return n
end

function setclass(x::Net, class)
    _checkclass(class)
    @set! x.class = class

    return x
end
function setclass!(n::Netlist, x::Net, class)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as $class because it does not exist in netlist.")
    n[i] = setclass(n[i], class)

    return n
end

function setreg(x::Net)
    @set! x.type = :reg

    return x
end
function setreg!(n::Netlist, x::Net)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as register because it does not exist in netlist.")
    n[i] = setreg(n[i])

    return n
end

function setwire(x::Net)
    @set! x.type = :wire

    return x
end
function setwire!(n::Netlist, x::Net)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as wire because it does not exist in netlist.")
    n[i] = setwire(n[i])

    return n
end

function setsigned(x::Net, signed)
    @set! x.signed = signed

    return x
end
function setsigned!(n::Netlist, x::Net, signed)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as signed = $signed because it does not exist in netlist.")
    n[i] = setsigned(n[i], signed)

    return n
end
