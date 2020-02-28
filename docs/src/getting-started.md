# Getting Started

BitSAD allows you to perform linear algebra arithmetic with bitstreams. A bitstream is a sequence of single bit values that represents some data. There are two types of bitstreams in BitSAD — stochastic bitstream ([`SBitstream`](@ref)) and deterministic bitstreams ([`DBitstream`](@ref)).

Stochastic bitstreams refer to bit sequences found in [stochastic computing](https://en.wikipedia.org/wiki/Stochastic_computing). Such bitstreams are modeled as a Bernoulli sequence whose mean is the real number being encoded. Deterministic bitstreams refer to [pulse density modulated](https://en.wikipedia.org/wiki/Pulse-density_modulation) audio data. In this case, the density of high bits is proportional to the amplitude of the audio signal.

## Creating Bitstreams

Creating a bitstream variable is straightforward:

```julia
x = SBitstream(0.1)
y = DBitstream()
```

Here `x` is a stochastic bitstream representing the real number 0.1. `y` is a deterministic bitstream. Deterministic bitstreams don't represent a single underlying value, so the constructor receives no arguments. Any bitstream object contains a queue of bits that holds the internal sequence of bits. Upon creation, neither `x` nor `y` have any bits in their queue. Below, in [Operating on Bitstreams](@ref), you will see how to add bits to their queues.

## Operating on Bitstreams

Both types of bitstreams inherit from a shared abstract type — [`AbstractBitstream`](@ref). If you were to create your own bitstream type, you would need to inherit from this abstract type. This allows us to define some shared operations that apply to all bitstreams. For example, we can push and pop bits from bitstreams:

```julia
x = SBitstream(0.1)
y = DBitstream()

push!(y, DBit(false)) # add a low bit to y's queue
pop!(y) == DBit(false) # true
print(pop!(x)) # prints a randomly generated bit according to Bernoulli(0.1)
pop!(y) # ERROR!
```

In the example above, we pushed and popped a bit from `y`, a deterministic bitstream. You cannot `pop!` from an empty `DBitstream`. This is allowed for `SBitstream`s though. Since a stochastic bitstream is modeled as a Bernoulli sequence, we sample from that distribution to generate a new bit whenever the queue is empty. If you do push bits onto an `SBitstream`'s queue, then those bits will be popped first before any new bits are generated.

Once there are bits in the queue (or not for `SBitstream`s), you can perform arithmetic:

```julia
x = SBitstream(0.1)
y = SBitstream(0.3)

# this expression will pop randomly generated bits
# from x and y, then add those bits and return
# a new SBitstream object with the result bit
# in its queue
x + y
```

## Under the Hood

What does the comment in the above example mean? In hardware, a bitstream computing program is represented by a circuit. A stream of bits enters the circuit inputs, and each bit is processed one-by-one to produce an output bitstream. So, `x + y` is an operator that works on single bits. We mentioned that all bitstreams have a queue containing the underlying sequence of bits. For `SBitstream`s, this is a sequence of `SBit`s. The `+` operator is defined for `SBit`s to add two inputs bit samples according to the hardware specification. In other words, when you run `x + y`, the result is computed exactly as it would be in hardware. In this way, BitSAD allows users to write programs at a high algorithmic level, simulate the hardware results, verify the results, then map the program to Verilog.