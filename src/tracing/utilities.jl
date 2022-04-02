_isbound(var) = !isnothing(var._op)

_getid(var::Ghost.Variable) = var.id
_getid(call::Ghost.Call) = call.id
_getid(x) = x

_gettapeop(var::Ghost.Variable) =
    _isbound(var) ? var._op :
                    error("Cannot get operation on tape for unbound variable.")

_gettapeval(input::Ghost.Input) = input.val
_gettapeval(call::Ghost.Call) = call.val
_gettapeval(var::Ghost.Variable) =
    _isbound(var) ? _gettapeval(var._op) :
                    error("Cannot get value on tape for unbound variable.")
_gettapeval(x) = x

_issimulatable(op) = false
_issimulatable(var::Ghost.Variable) = 
    (_gettapeval(var) isa Base.Broadcast.Broadcasted) ? _issimulatable(_gettapeop(var)) :
                                                        _gettapeval(var) isa SBitstreamLike
_issimulatable(input::Ghost.Input) = _gettapeval(input) isa SBitstreamLike
_issimulatable(call::Ghost.Call) = any(_issimulatable, call.args)

_isbcast(::typeof(Base.broadcasted)) = true
_isbcast(x) = false

_isinput(::Ghost.Input) = true
_isinput(x::Ghost.Variable) = _isinput(_gettapeop(x))
_isinput(x) = false

_isvariable(x::Ghost.AbstractOp) = true
_isvariable(x::Ghost.Variable) = true
_isvariable(x) = false

_isstruct(f::T) where T = isstructtype(T) && !(f isa Function)
