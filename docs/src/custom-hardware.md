# Custom hardware generation

A natural extension to BitSAD is user-defined hardware operators. For example, suppose you have a better implemention of a stochastic adder, and you want `x + y` (for `x`, `y` as `SBitstream`s) to map to instantiate your implementation. To facilitate this, BitSAD provides the [`AbstractHandler`](@ref) interface. Let's take a look at `SAddHandler`, BitSAD's default implementation for stochastic addition, to see how this works.

First, we need to create a subtype of `AbstractHandler`.

```julia
@kwdef mutable struct SAddHandler <: AbstractHandler
    id = 0
end
```

There is nothing special yet about this handler, but we will make note of the `id` field. For each call to [`HW.generate`](@ref), a single instance of `SAddHandler` will be responsible for generating the Verilog strings for every stochastic add operation in the DFG. Clearly, we do not want to name all instances generated the same, or the Verilog synthesizer will complain. The `id` field allows us to make each instance name unique. You will likely need some similar mechanism for your custom handler.

The next step is to _register_ the handler with BitSAD. For this, BitSAD provides the convenient [`HW.@register`](@ref) macro. Here's how it is used for `SAddHandler`.

```julia
@register(SAddHandler, +, begin
    [SBit, SBit] => [SBit]
    [SBit, Vector{SBit}] => [Vector{SBit}]
    [Vector{SBit}, SBit] => [Vector{SBit}]
    [Vector{SBit}, Vector{SBit}] => [Vector{SBit}]
    [SBit, Matrix{SBit}] => [Matrix{SBit}]
    [Matrix{SBit}, SBit] => [Matrix{SBit}]
    [Matrix{SBit}, Matrix{SBit}] => [Matrix{SBit}]
end)
```

The `@register` macro takes three arguments — a handler type, an operator, and a sequence of rules. The rules specify which combination of input argument types map to output arguments. The format of a rule is `[intype1, intype2, ...] => [outtype1, ...]`. Each type in the rule can be any type in Julia; the only restriction is that the types must be runtime types. BitSAD will try to match a node in the DFG based on the types of the arguments according to runtime dispatch. So, you might have defined `+(x::SBit, y::Real)`, but at runtime `y` might be `Float64`, `Int64`, or `UInt128`. Normally, you would have to specify a rule for every possible dispatch combination you want to match. But for some common cases, `@register` affords some conveniences. For example, `Number` matches any primitive numeric type. Below is a list of all convenience mappings.

| Keyword     | Types |
| :---------- | :---- |
| `Integer`   | `UInt8`, `Int8`, `UInt16`, `Int16`, `UInt32`, `Int32`, `UInt64`, `Int64`, `UInt128`, `Int128` |
| `Real`      | `Float16`, `Float32`, `Float64` |
| `Number`    | Everything for `Real` & `Integer` |
| `Matrix{_}` | `Array{_, 2}` |
| `Vector{_}` | `Array{_, 1}` |

Now, any time BitSAD encounters a node that accepts two `SBit`s as inputs, applies `+` on those inputs, and returns a `SBit`, it will invoke an instance of `SAddHandler` to generate the Verilog string. The next step is to define what happens when our handler is invoked.

```julia
function (handler::SAddHandler)(netlist::Netlist,
                                inputs::Vector{Variable},
                                outputs::Vector{Variable})
    # update netlist with inputs
    setsigned!(netlist, getname(inputs[1]), true)
    setsigned!(netlist, getname(inputs[2]), true)

    # compute output size
    lname, rname, outsize = handlebroadcast(inputs[1].name, inputs[2].name,
                                            getsize(netlist, getname(inputs[1])),
                                            getsize(netlist, getname(inputs[2])))

    # update netlist with output
    setsigned!(netlist, getname(outputs[1]), true)

    outstring = """
        $stdcomment
        // BEGIN add$(handler.id)
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_pp (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_p"))),
                .B($(rname("_p"))),
                .Y($(outputs[1].name)_p)
            );
        stoch_add_mat #(
                .NUM_ROWS($(outsize[1])),
                .NUM_COLS($(outsize[2]))
            ) add$(handler.id)_mm (
                .CLK(CLK),
                .nRST(nRST),
                .A($(lname("_m"))),
                .B($(rname("_m"))),
                .Y($(outputs[1].name)_m)
            );
        // END add$(handler.id)
        \n"""

    handler.id += 1

    return outstring
end
```

Every handler _must_ be callable and _must_ adhere to the interface: `(handler::AbstractHandler)(netlist::Netlist, inputs::Vector{Variable}, outputs::Vector{Variable})`. Refer to [Hardware API](@ref) for more details on `Netlist` or `Variable`. For now, let's take a look at what our handler does. First, it sets the input and output nets as _signed_. This means that the net name will have `_p` or `_m` appended on the end. This is required for `SBitstream`s whose signed representation is actually two nets — one for the positive channel and one for the negative channel. Notice that the handler also handles broadcasting. In cases where a matrix is added to a scalar, we need to use the repeat operator in Verilog to "broadcast" the scalar. Finally, the handler generates the output string that instantiates the `stoch_add_mat` module in Verilog. It also updates the `id` so that the next node gets a unique instance name.

At this point, it might seems like the handler code is quite complex. This is intentional to allow users the most flexibility in extending BitSAD.

## Complex custom handlers

To see just how flexible this interface can be, let's take a look at a more complex example — the delay buffer for deterministic bitstreams. Here is the code below:

```julia
using DataStructures: capacity

@kwdef mutable struct DelayBufferHandler <: AbstractHandler
    id = 0
    pushpopmap::Dict{Symbol, NamedTuple} = Dict{Symbol, NamedTuple}()
end

@register(DelayBufferHandler, popfirst!, [CircularBuffer{DBit}] => [DBit])
@register(DelayBufferHandler, push!, [CircularBuffer{DBit}, DBit] => [])

function (handler::DelayBufferHandler)(netlist::Netlist,
                                       inputs::Vector{Variable},
                                       outputs::Vector{Variable})
    buffname = inputs[1].name

    if length(inputs) == 1 && gettype(inputs[1]) == Symbol("CircularBuffer{DBit}")
        # record pop in map
        if haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = handler.pushpopmap[buffname][:push],
                                            pop = outputs[1],
                                            delay = handler.pushpopmap[buffname][:delay],
                                            processed = false)
        else
            error("Cannot find delay buffer $buffname in handler records.")
        end
    else
        # record push in map
        if haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = inputs[2],
                                            pop = handler.pushpopmap[buffname][:pop],
                                            delay = handler.pushpopmap[buffname][:delay],
                                            processed = false)
        else
            error("Cannot find delay buffer $buffname in handler records.")
        end
    end

    if haskey(handler.pushpopmap, buffname) && !any(isnothing, handler.pushpopmap[buffname]) && !handler.pushpopmap[buffname][:processed]
        outstring = """
            $stdcomment
            // BEGIN delay_buff$(handler.id)
            delay_buffer #(
                    .DELAY($(handler.pushpopmap[buffname][:delay]))
                ) delay_buff$(handler.id) (
                    .CLK(CLK),
                    .nRST(nRST),
                    .x($(handler.pushpopmap[buffname][:push])),
                    .y($(handler.pushpopmap[buffname][:pop]))
                );
            // END delay_buff$(handler.id)
            \n"""

        handler.pushpopmap[buffname] = (push = handler.pushpopmap[buffname][:push],
                                        pop = handler.pushpopmap[buffname][:pop],
                                        delay = handler.pushpopmap[buffname][:delay],
                                        processed = true)

        handler.id += 1
    else
        outstring = ""
    end

    return outstring
end
```

BitSAD treats `CircularBuffer{DBit}`s (from Datastructures.jl) as delay buffers. Yet, one tricky aspect of implementing delay buffers is that they will show up in two places in the DFG. A `popfirst!` operation will get the output of the buffer, and a `push!` operation will add an input to the buffer. Even though there are two operations in Julia, they correspond to a single instance in Verilog. To facilitate this, the code above registers both operations to the same handler. So, the same handler instance will be invoked regardless of which operation is encountered. Depending on whether we are handling a `push!` or `popfirst!`, we record what is being pushed or popped in `pushpopmap` — an internal handler field to keep track of all the delay buffer relationships. This field maps the name of a delay buffer (the first argument to `push!` or `popfirst!` in Julia) to a named tuple. This named tuple stores the name of what net is pushed, popped, the amount of delay, and whether the handler as already processed the Verilog string for this particular buffer.

The latter half of the function will actually output the Verilog string for a delay buffer only once all the information has been acquired in the named tuple. If the handler does not have all the information to generate the Verilog string, then it just returns an empty string. Already, this example is fairly complex. But this isn't all the code required! You may notice that we use `pushpopmap[_][:delay]`, but it is never set in any of the code above. How does this delay information get set? That is covered in the next section.

## Runtime extraction for handlers

So far, we have only covered the required functions of the `AbstractHandler` interface. There are some optional functions you can implement to gain even more flexibility. Below, we show the `extractrtinfo!` interface function for the delay buffer.

```julia
function extractrtinfo!(handler::DelayBufferHandler, innames, outname, opname, inputs, output, op)
    if op == popfirst!
        buffname = innames[1]

        if !haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = nothing, pop = nothing, delay = capacity(inputs[1]), processed = false)
        end
    elseif op == push!
        buffname = innames[1]

        if !haskey(handler.pushpopmap, buffname)
            handler.pushpopmap[buffname] = (push = nothing, pop = nothing, delay = capacity(inputs[1]), processed = false)
        end
    end
end
```

You will recall from [Hardware internals](@ref) that before the Verilog is generated, BitSAD calls a function to extract runtime information from the DFG to update the `Module`. During this phase, your handler can also access the runtime information for certain nodes. By implementing a function with the same signature as above, you will have access to the following:

- `innames`: a vector of symbols of the input net names
- `outname`: a symbol of the output net name
- `opname`: a symbol for the operator name stored in the DFG
- `inputs`: the actual runtime input arguments
- `output`: the actual runtime return value
- `op`: the function called at runtime (note that for callable structs, this is the instance of the struct)

It is important to remember that runtime extraction happens _before_ the DFG is traversed for optimization and hardware generation. So, the DFG will be unoptimized, and fields inside your handler will not be populated yet with netlist information. Instead, this interface is provided to extract _only_ the information the requires access to the runtime objects. For example, to set the delay for a delay buffer, we need to call `DataStructures.capacity(inputs[1])`. Lastly, it is important to remember that this function is only called for your handler when a node that matches the `@register` rules is encountered.

# Hardware API

All custom hardware generation is based on inheriting from `AbstractHandler`. You are only required to `@register` your handler and define it as a callable struct.

```@docs
AbstractHandler
HW.@register
```

There are optional functions as part of the interface as well. You can override these for more flexibility.

```@docs
HW.allowconstreplacement
HW.extractrtinfo!
```