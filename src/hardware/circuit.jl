using MacroTools: postwalk, @q

function extracttypes!(m::Module, innames, outname, f, args...)
    # evaluate function
    retval = f(args...)

    # get types
    intypes = Symbol.(typeof.(args))
    outtype = Symbol(typeof(retval))

    # push types onto module
    inputs = Variable[]
    outputs = [Variable(outname, outtype)]
    for (inname, intype) in zip(innames, intypes)
        push!(inputs, Variable(inname, intype))
    end
    updatetype!(m, inputs, outputs, nameof(f))

    return retval
end

function getparameters!(parametermap, params)
    fields = Expr[]
    for param in params
        @capture(param, var_::T_ => val_) ||
            error("Cannot parse parameter: $param (use syntax 'paramname::paramtype => paramvalue')")
        parametermap[var] = val
        push!(fields, @q($var::$T = $val))
    end

    return parametermap, fields
end

createstruct(name, fields) = esc(@q begin
    Base.@kwdef struct $name
        $(fields...)
    end
end)

stripparameters(x; prefix) = @capture(x, p_.s_) && p == prefix ? s : x

issymbol(s) = false
issymbol(s::Symbol) = true

function parsenode!(m::Module, opd, op, args, modcalls, modsym)
    inputs = map(x -> Variable(x, :Any), args)
    outputs = map(x -> Variable(x, :Any), [opd])
    addnode!(m, inputs, outputs, op)

    return @q BitSAD.HW.extracttypes!($modsym, $args, $(QuoteNode(:($opd))), $op, $(modcalls...))
end

function parseexpr!(m::Module, expr; prefix, modsym, opd = nothing, level = 1, depth = 1, counter = 1)
    opd = isnothing(opd) ? Symbol("net_$(level)_$(depth)_$counter") : opd

    if issymbol(stripparameters(expr; prefix = prefix))
        return stripparameters(expr; prefix = prefix), expr
    else
        @capture(expr, op_(args__)) || error("Cannot parse statement $expr.")
    end

    wires = Symbol[]
    modcalls = Union{Expr, Symbol}[]
    for (i, arg) in enumerate(args)
        wire, modcall = parseexpr!(m, arg; prefix = prefix, modsym = modsym,
                                           level = level, depth = depth + 1, counter = i)
        push!(wires, wire)
        push!(modcalls, modcall)
    end

    return opd, parsenode!(m, opd, op, wires, modcalls, modsym)
end

function parsecircuit!(m::Module, f)
    (@capture(f, (dut_::T_)(args__) -> body_) && T == m.name) ||
        error("Cannot parse circuit description.")

    # original function definition
    funcdef = @q begin
        function ($dut::$T)($(args...))
            $body
        end
    end

    # separate body into statements
    # body = postwalk(x -> stripparameters(x; prefix = dut), body)
    @capture(body, begin statements__ end) || error("Cannot parse circuit description.")

    # gensym for modified function definition
    modsym = gensym("m")

    # step through body of function and extract DFG
    modstatements = Expr[]
    for (i, statement) in enumerate(statements)
        @capture(statement, opd_ = rhs_) ?
            push!(modstatements, @q $opd = $(parseexpr!(m, rhs; prefix = dut, modsym = modsym, opd = opd, level = i)[2])) :
        @capture(statement, return rargs__) ? println("Return: $rargs") :
        error("Cannot parse statement $statement.")
    end

    # create modified function definition (for type extraction at runtime)
    modfdef = @q begin
        function extracttypes!($dut::$T, $modsym::BitSAD.HW.Module, $(args...))
            $(modstatements...)
        end
    end

    return esc(funcdef), esc(modfdef)
end

"""
    @circuit

Create a new BitSAD circuit by specifying the name, parameters,
and implementation algorithm.

# Examples
```julia
m = @circuit Foo begin
    parameters : [
        a => 0.125
        b => 10
    ]

    circuit : (dut::Foo)(x::DBit) -> begin
        y = dut.a * x
        z = y + dut.b

        return z
    end
end
```
"""
macro circuit(name, body)
    parametermap = Dict{Symbol, Number}()
    fields = Expr[]
    funcdef = body
    modfdef = body
    m = Module(name = Symbol("$name"))

    # walk through definition
    postwalk(body) do statement
        # extract parameters
        if @capture(statement, parameters : [params__])
            m.parameters, fields = getparameters!(parametermap, params)
            println(parametermap)
        end

        # extract circuit
        if @capture(statement, circuit : f_)
            funcdef, modfdef = parsecircuit!(m, f)
        end

        return statement
    end

    structdef = createstruct(name, fields)

    return @q begin
        $structdef

        $funcdef

        $m, $modfdef
    end
end