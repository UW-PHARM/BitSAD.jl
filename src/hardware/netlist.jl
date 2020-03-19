using Base: @kwdef

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
    name::String
    type::Symbol = :wire
    class::Symbol = :internal
    signed::Bool = false
    size::Tuple{Int, Int}

    function Net(name, type, class, signed, size)
        _checktype(type)
        _checkclass(class)
        _checksize(size)

        new(name, type, class, signed, size)
    end
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

find(n::Netlist, x::String) = findfirst(λ -> λ.name == x, n)
contains(n::Netlist, x::String) = !isnothing(find(n, x))

function getsize(n::Netlist, x::String)
    i = find(n, x)
    isnothing(i) && error("Cannot get size for net $x since it does not exist in netlist.")

    return n[i].size
end
getsize(n::Netlist, x::Vector{String}) = map(λ -> getsize(n, λ), x)

delete!(n::Netlist, x::String) = deleteat!(n, find(n, x))

function update!(n::Netlist, x::Net)
    i = findfirst(λ -> λ.name == x.name, n)
    if isnothing(i)
        push!(n, x)
    else
        n[i] = x
    end

    return n
end

function setreg!(n::Netlist, x::String)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as register because it does not exist in netlist.")
    update!(n, Net(name = x, type = :reg, class = n[i].class, signed = n[i].signed, size = n[i].size))

    return n
end

function setwire!(n::Netlist, x::String)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as wire because it does not exist in netlist.")
    update!(n, Net(name = x, type = :wire, class = n[i].class, signed = n[i].signed, size = n[i].size))

    return n
end

function setsigned!(n::Netlist, x::String, signed::Bool)
    i = find(n, x)
    isnothing(i) && error("Cannot set net $x as signed = $signed because it does not exist in netlist.")
    update!(n, Net(name = x, type = n[i].type, class = n[i].class, signed = signed, size = n[i].size))

    return n
end