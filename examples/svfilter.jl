using BitSAD
using DataStructures

struct SVFilter
    f::Float64
    q::Float64
    delay₁::CircularBuffer{DBit}
    delay₂::CircularBuffer{DBit}
    ΣΔ₁::SDM
    ΣΔ₂::SDM

    function SVFilter(f, q, delay₁, delay₂, ΣΔ₁, ΣΔ₂)
        svfilter = new(f, q, delay₁, delay₂, ΣΔ₁, ΣΔ₂)
        fill!(svfilter.delay₁, zero(DBit))
        fill!(svfilter.delay₂, zero(DBit))

        return svfilter
    end
end
SVFilter(f::Real, q::Real, delay::Integer) =
    SVFilter(f, q, CircularBuffer{DBit}(delay), CircularBuffer{DBit}(delay), SDM(), SDM())

function (filter::SVFilter)(x::DBit)
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