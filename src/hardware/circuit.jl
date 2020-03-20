using MacroTools: postwalk, @q

_padtuple(x, n) = length(x) < n ? (x..., ones(n - length(x))...) : x
isconstant(x) = occursin(r"^-?\d+$", string(x)) || occursin(r"^-?\d+\.\d+$", string(x))

function extractrtinfo!(m::Module, netlist::Netlist, innames, outname, f, isbroadcast, submod, args...)
    # evaluate function
    retval = isbroadcast ? f.(args...) : f(args...)

    # get types
    intypes = Symbol.(typeof.(args))
    outtype = Symbol(typeof(retval))

    # get sizes
    insizes = _padtuple.(size.(args), 2)
    outsize = _padtuple(size(retval), 2)

    # push types onto module and netlist
    inputs = Variable[]
    outputs = ismissing(outname) ? Variable[] : [Variable(outname, outtype)]
    for (inname, intype, insize) in zip(innames, intypes, insizes)
        push!(inputs, Variable(inname, intype))
        if !contains(netlist, string(inname)) && all(insize .!= 0)
            if isconstant(inname)
                update!(netlist, Net(name = string(inname), class = :constant, size = insize))
            elseif haskey(m.parameters, inname)
                update!(netlist, Net(name = string(inname), class = :parameter, size = insize))
            else
                update!(netlist, Net(name = string(inname), class = :internal, size = insize))
            end
        end
    end

    # update operator if operation is submodule
    if !isnothing(submod)
        v = findnode(m.dfg, string.(innames), [string(outname)], submod)
        operator = Symbol(typeof(f))
        !isempty(v) && set_prop!(m.dfg, v[1], :operator, operator)
    else
        operator = Symbol(f)
    end
    updatetype!(m, inputs, outputs, operator)

    # update output in netlist
    if !ismissing(outname) && !contains(netlist, string(outname)) && all(outsize .!= 0)
        update!(netlist, Net(name = string(outname), class = :internal, size = outsize))
    end

    # allow handler to access runtime information
    op = Operation([intypes...], ismissing(outname) ? Symbol[] : [outtype], operator)
    if haskey(m.handlers, op)
        handler = m.handlers[op]
    else
        handler = gethandler(op)()
        m.handlers[op] = handler
    end
    extractrtinfo!(handler, innames, outname, submod, args, retval, f)

    return retval
end

function setinputs!(netlist::Netlist, innames)
    for inname in innames
        i = find(netlist, inname)
        if isnothing(i)
            error("Cannot set $inname as input because it does not exist in netlist.")
        else
            update!(netlist, Net(name = inname,
                                 type = netlist[i].type,
                                 class = :input,
                                 signed = netlist[i].signed,
                                 size = netlist[i].size))
        end
    end

    return netlist
end

function setoutputs!(netlist::Netlist, outnames)
    for outname in outnames
        i = find(netlist, outname)
        if isnothing(i)
            error("Cannot set $outname as output because it does not exist in netlist.")
        else
            update!(netlist, Net(name = inname,
                                 type = netlist[i].type,
                                 class = :output,
                                 signed = netlist[i].signed,
                                 size = netlist[i].size))
        end
    end

    return netlist
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

function getsubmodules!(submodulemap, submodules)
    fields = Expr[]
    for submodule in submodules
        @capture(submodule, var_::T_) ||
            error("Cannot parse submodule: $submodule (use syntax 'modname::modtype')")
        submodulemap[var] = Symbol(T)
        push!(fields, @q($var::$T))
    end

    return submodulemap, fields
end

createinnerconstructor(name, initdef, fields) = isnothing(initdef) ? nothing :
    @q begin
        function $name($(fields...))
            $initdef
        end
    end

createstruct(name, pfields, sfields, constructor) = isnothing(constructor) ?
    esc(@q begin
        Base.@kwdef struct $name
            $(pfields...)
            $(sfields...)
        end
    end) :
    esc(@q begin
        Base.@kwdef struct $name
            $(pfields...)
            $(sfields...)

            $constructor
        end
    end)

function stripbroadcast(x)
    m = match(r"^\.(.*)$", string(x))

    return isnothing(m) ? (false, x) : (true, Symbol(m.captures[1]))
end
stripparameters(x; prefix) = @capture(x, p_.s_) && p == prefix ? s : x
stripargument(x) = @capture(x, name_::T_) ? name : error("Cannot strip argument expression $x")

issymbol(s) = false
issymbol(s::Symbol) = true

function parsenode!(m::Module, opd, op, args, prefix, modcalls, modsym, netsym)
    inputs = map(x -> Variable(x, :Any), args)
    outputs = ismissing(opd) ? Variable[] : map(x -> Variable(x, :Any), [opd])
    isbroadcast, op = stripbroadcast(op)
    op = opalias(op)

    opname = stripparameters(op; prefix = prefix)
    addnode!(m, inputs, outputs, opname)

    submod = (opname == op) ? nothing : opname

    return @q BitSAD.HW.extractrtinfo!($modsym, $netsym, $args, $(QuoteNode(:($opd))), $op, $isbroadcast, $(QuoteNode(:($submod))), $(modcalls...))
end

function parseexpr!(m::Module, expr; prefix, modsym, netsym, opd = nothing, level = 1, depth = 1, counter = 1)
    opd = isnothing(opd) ? Symbol("net_$(level)_$(depth)_$counter") : opd

    if issymbol(stripparameters(expr; prefix = prefix))
        return stripparameters(expr; prefix = prefix), expr
    else
        @capture(expr, op_(args__)) || error("Cannot parse statement $expr.")
    end

    wires = Symbol[]
    modcalls = Union{Expr, Symbol}[]
    for (i, arg) in enumerate(args)
        wire, modcall = parseexpr!(m, arg; prefix = prefix, modsym = modsym, netsym = netsym,
                                           level = level, depth = depth + 1, counter = i)
        push!(wires, wire)
        push!(modcalls, modcall)
    end

    return opd, parsenode!(m, opd, op, wires, prefix, modcalls, modsym, netsym)
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
    netsym = gensym("netlist")

    # step through body of function and extract DFG
    modstatements = Expr[]
    rargs = Symbol[]
    for (i, statement) in enumerate(statements)
        @capture(statement, opd_ = rhs_) ?
            push!(modstatements,
                @q $opd = $(parseexpr!(m, rhs; prefix = dut, modsym = modsym, netsym = netsym, opd = opd, level = i)[2])) :
        @capture(statement, op_(arg__)) ?
            push!(modstatements,
                parseexpr!(m, statement; prefix = dut, modsym = modsym, netsym = netsym, opd = missing, level = i)[2]) :
        @capture(statement, return (rvals__)) ? vcat(rargs, rvals) :
        @capture(statement, return rval_) ? vcat(rargs, [rval]) :
        error("Cannot parse statement $statement.")
    end

    # create modified function definition (for type extraction at runtime)
    innames = string.(stripargument.(args))
    outnames = string.(Symbol.(rargs))
    modfdef = @q begin
        function extractrtinfo!($dut::$T, $modsym::BitSAD.HW.Module, $netsym::BitSAD.HW.Netlist, $(args...))
            $(modstatements...)
            BitSAD.HW.setinputs!($netsym, $innames)
            BitSAD.HW.setoutputs!($netsym, $outnames)
        end
    end

    return esc(funcdef), esc(modfdef)
end

"""
    @circuit

Create a new BitSAD circuit by specifying the name, parameters,
submodules, initialization, and implementation algorithm.

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
    submodulemap = Dict{Symbol, Symbol}()
    pfields = Expr[]
    sfields = Expr[]
    funcdef = body
    modfdef = body
    initdef = nothing
    m = Module(name = Symbol("$name"))

    # walk through definition
    postwalk(body) do statement
        # extract parameters
        if @capture(statement, parameters : [params__])
            m.parameters, pfields = getparameters!(parametermap, params)
        end

        # extract submodules
        if @capture(statement, submodules : [submods__])
            m.submodules, sfields = getsubmodules!(submodulemap, submods)
        end

        # extract initialization
        if @capture(statement, initialize : initroutine_)
            initdef = rmlines(initroutine)
        end

        # extract circuit
        if @capture(statement, circuit : f_)
            funcdef, modfdef = parsecircuit!(m, f)
        end

        return statement
    end

    innerconstructor = createinnerconstructor(name, initdef, vcat(collect(keys(parametermap)), collect(keys(submodulemap))))
    structdef = createstruct(name, pfields, sfields, innerconstructor)

    return @q begin
        $structdef

        $funcdef

        $m, $modfdef
    end
end