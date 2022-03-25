# Creating a custom `SBitstream` operator

In most of the tutorials, we've discussed writing functions of `SBitstream`s, simulating those functions, and generating hardware for those functions. This already covers a large variety of circuits, but in some cases, your circuit will need an custom operator that is not already defined in BitSAD. Defining this operator so that it is simulatable and synthesizable like all the standard BitSAD operators is what this how-to will cover. The entire process requires three pieces:

1. Define a Julia function
2. Associate the function with a simulator
3. Associate the function with a hardware handler

## Defining the Julia operator

Let's start with the easiest step --- defining what we want our operator to do to the encoded value of the `SBitstream` (this is not the bit-level behavior!). We'll make up a non-sensical operator here, `addtimes(x, y)`, which adds two `SBitstream`s then multiplies the result by the first `SBitstream`.

{cell=custom-soperator}
```julia
using BitSAD

addtimes(x::SBitstream, y::SBitstream) = SBitstream((float(x) + float(y)) * float(x))

x = SBitstream(0.4)
y = SBitstream(0.1)
addtimes(x, y)
```

It looks like the encoded floating point value for our function is correct.

## Associating `addtimes` with a simulator

Next, we need to be able to simulate `addtimes` at the bit-level. To do this, we'll define a simulator --- a struct that operates on `SBit`s and stores stateful information for this operation. We'll make use of the existing simulators in BitSAD to do this, which you can do in your code, or you can define a simulator completely from scratch. All that matters is that your simulator can be called on `(x::SBit, y::SBit)`.

{cell=custom-soperator}
```julia
using BitSAD: SSignedAdder, SSignedMultiplier, SSignedDecorrelator

struct AddTimeser
    adder::SSignedAdder
    multiplier::SSignedMultiplier
    decorrelator::SSignedDecorrelator
end
AddTimeser() = AddTimeser(SSignedAdder(),
                          SSignedMultiplier(),
                          SSignedDecorrelator())

function (addtimeser::AddTimeser)(x::SBit, y::SBit)
    xdecorrelate = addtimeser.decorrelator(x)
    z = addtimeser.multiplier(addtimeser.adder(x, y), xdecorrelate)

    return z # our return must be an SBit too
end
```

So far, BitSAD doesn't know that it should map simulated calls to `addtimes` to an instance of `AddTimeser`. To do this, we need to _extend_ the simulator interface.

{cell=custom-soperator}
```julia
# SBitstreamLike = Union{SBitstream, AbstractArray{<:SBitstream}}
using BitSAD: SBitstreamLike

# BitSAD will recognize call signatures that match this as primitive calls
# this means BitSAD won't "look inside" the call
BitSAD.is_trace_primitive(::Type{typeof(addtimes)},
                          ::Type{<:SBitstream},
                          ::Type{<:SBitstream}) = true

# getsimulator returns a new instance of the simulator for the primitive call
# in our case, we return a new AddTimeser
BitSAD.getsimulator(::typeof(addtimes), ::SBitstream, ::SBitstream) = AddTimeser()
# we need to explicitly handle broadcasted calls to addtimes
# here, we return an array of AddTimesers (this is probably what you want to do)
BitSAD.is_trace_primitive(::Type{Base.broadcasted},
                          ::Type{typeof(addtimes)},
                          ::Type{<:SBitstreamLike},
                          ::Type{<:SBitstreamLike}) = true
BitSAD.getsimulator(::typeof(Base.broadcasted),
                    ::typeof(addtimes),
                    x::SBitstreamLike,
                    y::SBitstreamLike) = BitSAD.getsimulator.(addtimes, x, y)
```

Now, whenever BitSAD sees a function call in a simulated program that matches our `BitSAD.is_trace_primitive` signature, it will call `BitSAD.getsimulator` to create a new simulator instance, and it will forward the popped bits to that simulator.

!!! tip
    We implemented the broadcasted simulator for `addtimes` as many `AddTimesers` in the same shape as the broadcasted arrays `x` and `y`. You can also create a simulator specifically for broadcasted calls that operates on arrays of `SBit`s. Instead of returning an array of simulators, you would return a single instance of this special broadcast simulator. BitSAD will understand either option and pass the popped bits appropriately.

Let's see if our simulator works.

{cell=custom-soperator}
```julia
sim = simulatable(addtimes, x, y)
sim(addtimes, x, y)
```

## Associating `addtimes` with a hardware handler

When BitSAD generates hardware, it uses the same program tracing functionality used in simulation to create a data-flow graph (DFG) of the program. Then it applies a series of transformation passes on the graph to apply optimizations. Finally, it traverses the graph from inputs to outputs, maintaining a [`BitSAD.Netlist`](#) along the way. At each node, it invokes the _hardware handler_ associated with that node. A hardware handler is responsible for generating the SystemVerilog instantiation code for each node of a certain type. For example, the `BitSAD.SAddHandler` writes the SystemVerilog code to instantiate every `+` operation in the DFG. The reason a single handler instance is called repeatedly to generate each piece of SystemVerilog is so that the handler can ensure that SystemVerilog instance naming is unique.

Suppose we have the following SystemVerilog module:
```verilog
module AddTimes(CLK, nRST, x_p, x_m, y_p, y_m, z_p, z_m);

// implementation

endmodule
```

Let's write a handler in BitSAD that instantiates a new `AddTimes` whenever `addtimes` is encountered in the DFG.

{cell=custom-soperator}
```julia
using BitSAD: Net, Netlist, name, netsize, handle_broadcast_name

struct SAddTimesHandler end

BitSAD.init_state(::SAddTimesHandler) = (id = 0,)

function (handler::SAddTimesHandler)(buffer,
                                     netlist::Netlist,
                                     state,
                                     inputs::Netlist,
                                     outputs::Netlist)
    # compute input naming
    # handle_broadcast_name is utility that uses the SystemVerilog repeat
    # operator to "broadcast" a scalar input to the correct size
    lname, rname = handle_broadcast_name(name(inputs[1]), name(inputs[2]),
                                         netsize(inputs[1]), netsize(inputs[2]))

    # always use netsize to get the size of nets
    # net sizes may be strings not integers
    outsize = netsize(outputs[1])

    write(buffer, """
        // BEGIN addtimes$(state.id)
        AddTimes add$(state.id) (
                .CLK(CLK),
                .nRST(nRST),
                .x_p($(lname("_p"))),
                .x_m($(lname("_m"))),
                .y_p($(rname("_p"))),
                .y_m($(rname("_m"))),
                .z_p($(name(outputs[1]))_p),
                .z_m($(name(outputs[1]))_m)
            );
        // END addtimes$(state.id)
        \n""")

    return buffer, (id = state.id + 1,)
end
```

Our `SAddTimesHandler` (stochastic `addtimes` handler) has some state associated with it. We use this to keep track of how many instances of the Verilog module we have created. The handler is callable according to the handler interface which accepts the arguments:

1. `buffer`: the IO stream to write our SystemVerilog to
2. `netlist`: the current circuit `Netlist`
3. `state`: the handler state
4. `inputs`: a `Netlist` of inputs
5. `outputs`: a `Netlist` of outputs

By convention, BitSAD represents `SBitstream` nets as the net's name with "_p" or "_m" appended. We also used the [`BitSAD.handle_broadcast_name`](#) to adjust the input names in the presence of a broadcast. Writing to `buffer` is the important piece of code here. This is the SystemVerilog code that will be produced for each `addtimes`. You can see we used the `id` field to name the module instance uniquely, and we passed in the standard `CLK` and `nRST` signals.

At this stage, like our simulator, BitSAD still does not know how to associate nodes in the DFG with our handler. We extend a similar interface to the simulator.

{cell=custom-soperator}
```julia
BitSAD.gethandler(::Bool,
                  ::Type{typeof(addtimes)},
                  ::Type{<:SBitstreamLike},
                  ::Type{<:SBitstreamLike}) = SAddTimesHandler()
```

The first `Bool` argument is `true` when the operation is broadcasted and `false` if not. If your operator does not deal with broadcasting, then you can ignore this argument.

!!! tip
    We don't need to redefine this operation as primitive, since we already extended `BitSAD.is_trace_primitive`. If you want, you can define `BitSAD.is_simulatable_primitive` and `BitSAD.is_hardware_primitive` separately (by default they call `BitSAD.is_trace_primitive`).

Let's generate some hardware!

{cell=custom-soperator}
```julia
verilog_string, _ = generatehw(addtimes, x, y)
print(verilog_string)
```

And that's all there is to creating custom operators in BitSAD for `SBitstream`s.
