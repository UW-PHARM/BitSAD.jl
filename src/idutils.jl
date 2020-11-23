# generate new ids
_genid() = unsafe_trunc(UInt32, uuid4().value)

# for squashing many ids into one (e.g. input args)
_getidstr(x::SBitstream) = digits(UInt8, x.id; base = 16, pad = 8)
_getidstr(x) = Vector{UInt8}(string(x))
_getidstr(x::VecOrMat) = mapreduce(_getidstr, vcat, x)

# useful for broadcasting getproperty
id(s::SBitstream) = s.id
id(x) = x