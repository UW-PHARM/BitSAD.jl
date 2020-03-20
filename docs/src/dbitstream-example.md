# Walking through a `DBitstream` Example

Let's walk through a `DBitstream` example for a [state-variable filter](https://www.earlevel.com/main/2003/03/02/the-digital-state-variable-filter/). Below is a diagram that illustrates the filter dataflow graph.

![Digital SVF](https://www.earlevel.com/DigitalAudio/images/StateVarBlock.gif)

Similar to [Walking through an `SBitstream` Example](@ref), we begin by creating a circuit that represents our module or algorithm.

```julia
using BitSAD
using DataStructures

circuit = @circuit SVFilter begin
    parameters : [
        f::Float64 => 0.125,
        q::Float64 => 1.875
    ]

    submodules : [
        delay₁::CircularBuffer{DBit},
        delay₂::CircularBuffer{DBit},
        ΣΔ₁::SDM,
        ΣΔ₂::SDM
    ]

    initialize : begin
        svfilter = new(f, q, delay₁, delay₂, ΣΔ₁, ΣΔ₂)
        fill!(svfilter.delay₁, zero(DBit))
        fill!(svfilter.delay₂, zero(DBit))

        return svfilter
    end

    circuit : (filter::SVFilter)(x::DBit) -> begin
        # get delay buffer values
        d₁old = popfirst!(filter.delay₁)
        d₂old = popfirst!(filter.delay₂)

        # calculate new buffer values and filter output
        d₂ = filter.ΣΔ₂(filter.f * d₁old + d₂old)
        d₁ = filter.ΣΔ₁(filter.f * (x - d₂ - filter.q * d₁old) + d₁old)

        # push new values into delay buffers
        push!(filter.delay₁, d₁)
        push!(filter.delay₂, d₂)

        return d₁
    end
end

SVFilter(f::Real, q::Real, delay::Integer) =
    SVFilter(f, q, CircularBuffer{DBit}(delay), CircularBuffer{DBit}(delay), SDM(), SDM())
```

Here the module is a little more complex that the `SBitstream` example. First, we have two filter constants, `f` and `q`, that are parameters in our module just like the stochastic bitstream example. But we also have `delay₁`, `delay₂`, `ΣΔ₁`, and `ΣΔ₂`. These fields don't represent parameters, but rather they represent _submodules_. They will be treated differently by BitSAD when the hardware is generated. In general, both the parameters and submodules will be fields in our struct even though they are treated differently for the purpose of generating hardware. Notice that we used `CircularBuffer` fields which is a type from DataStructures.jl. BitSAD will interpret these blocks as delay buffers (shift registers). The `SDM` type is provided by BitSAD, and it represents a sigma-delta modulator which is useful to convert binary numbers into deterministic bitstreams. You may also want to define an inner constructor that does any initialization for your struct. This is done by specifying the `initialize` field that contains the body of the inner constructor. The inner constructor will always accept arguments with names that match the parameter and submodule names you specified. Lastly, we also used an outer constructor to make creating a new `SVFilter` easy. These are conveniences for this program but have no effect on BitSAD's interpretation of the module.

Like we did for stochastic bitstreams, we make our struct callable where the function body defines how the module operates on a single sample of input bits. The implementation above should read as a straightforward implementation of the bandpass filter in the figure above. Once we have our filter module, we can test it. Below, there are two functions defined for reading and writing a DAT file that contains PDM audio data. These are just helper functions, and they are not relevant to understanding BitSAD. But they should give you an idea of how easy it is to have a bitstream computing design embedded inside a larger Julia program. Instead, we call your attention to the lines towards the end of the code block which instantiate a `SVFilter`, read in some audio data, then pass the audio data through the filter and store the results in an output `DBitstream`.

```julia
function readdat(filename)
    s = DBitstream()
    samplerate = 0
    nchannels = 0

    for line in eachline(filename)
        m = match(r"; Sample Rate (\d+)", line)
        if !isnothing(m)
            samplerate = parse(Int, m.captures[1])
        end

        m = match(r"; Channels (\d+)", line)
        if !isnothing(m)
            nchannels = parse(Int, m.captures[1])
        end

        m = match(r"\s+[\de\-\.]+\s+([\d\.\-]+)\s+", line)
        if !isnothing(m)
            bit = round(parse(Float64, m.captures[1]))
            push!(s, DBit(bit))
        end
    end

    return s, samplerate, nchannels
end

function writedat(filename, s::DBitstream; samplerate, nchannels)
    open(filename, "w") do io
        write(io, "; Sample Rate $samplerate\n")
        write(io, "; Channels $nchannels\n")
        for i in 1:length(s)
            bit = pop!(s)
            write(io, " $((i - 1) * (1 / samplerate))  $(float(bit)) \n")
        end
    end
end

svfilter = SVFilter(0.125, 1.875, 1)
x, samplerate, nchannels = readdat("./examples/Expchirp.dat")
y = DBitstream()

for i in 1:length(x)
    push!(y, svfilter(pop!(x)))
end

writedat("./examples/Expchirp-output.dat", y; samplerate = samplerate, nchannels = nchannels)
```