var documenterSearchIndex = {"docs":
[{"location":"dbitstream-example/#Walking-through-a-DBitstream-Example-1","page":"Deterministic Bitstream Walkthrough","title":"Walking through a DBitstream Example","text":"","category":"section"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"Let's walk through a DBitstream example for a state-variable filter. Below is a diagram that illustrates the filter dataflow graph.","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"(Image: Digital SVF)","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"Similar to Walking through an SBitstream Example, we begin by creating a struct that represents our module or algorithm.","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"using BitSAD\nusing DataStructures\n\nstruct SVFilter\n    f::Float64\n    q::Float64\n    delay₁::CircularBuffer{DBit}\n    delay₂::CircularBuffer{DBit}\n    ΣΔ₁::SDM\n    ΣΔ₂::SDM\n\n    function SVFilter(f, q, delay₁, delay₂, ΣΔ₁, ΣΔ₂)\n        svfilter = new(f, q, delay₁, delay₂, ΣΔ₁, ΣΔ₂)\n        fill!(svfilter.delay₁, zero(DBit))\n        fill!(svfilter.delay₂, zero(DBit))\n\n        return svfilter\n    end\nend\nSVFilter(f::Real, q::Real, delay::Integer) =\n    SVFilter(f, q, CircularBuffer{DBit}(delay), CircularBuffer{DBit}(delay), SDM(), SDM())","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"Here the module is a little more complex that the SBitstream example. First, we have two filter constants, f and q, that are parameters in our module just like the stochastic bitstream example. But we also have delay₁, delay₂, ΣΔ₁, and ΣΔ₂. These fields don't represent parameters, but rather they represent submodules. They will be treated differently by BitSAD when the hardware is generated. In general, any numeric field is treated as a parameter, and any other field is mapped to a known submodule by BitSAD or we assume the submodule name is the same as the type of the parameter. Notice that we used CircularBuffer fields which is a type from DataStructures.jl. BitSAD will interpret these blocks as delay buffers (shift registers). The SDM type is provided by BitSAD, and it represents a sigma-delta modulator which is useful to convert binary numbers into deterministic bitstreams. Lastly, we also used an inner constructor and outer constructor to make creating a new SVFilter easy. These are conveniences for this program but have no effect on BitSAD's interpretation of the module.","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"Like we did for stochastic bitstreams, we make our struct callable where the function body defines how the module operates on a single sample of input bits.","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"function (filter::SVFilter)(x::DBit)\n    # get delay buffer values\n    d₁old = popfirst!(filter.delay₁)\n    d₂old = popfirst!(filter.delay₂)\n\n    # calculate new buffer values and filter output\n    d₂ = filter.ΣΔ₂(filter.f * d₁old + d₂old)\n    d₁ = filter.ΣΔ₁(filter.f * (x - d₂ - filter.q * d₁old) + d₁old)\n\n    # push new values into delay buffers\n    push!(filter.delay₁, d₁)\n    push!(filter.delay₂, d₂)\n\n    return d₁\nend","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"The implementation above should read as a straightforward implementation of the bandpass filter in the figure above. Once we have our filter module, we can test it. Below, there are two functions defined for reading and writing a DAT file that contains PDM audio data. These are just helper functions, and they are not relevant to understanding BitSAD. But they should give you an idea of how easy it is to have a bitstream computing design embedded inside a larger Julia program.","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"function readdat(filename)\n    s = DBitstream()\n    samplerate = 0\n    nchannels = 0\n\n    for line in eachline(filename)\n        m = match(r\"; Sample Rate (\\d+)\", line)\n        if !isnothing(m)\n            samplerate = parse(Int, m.captures[1])\n        end\n\n        m = match(r\"; Channels (\\d+)\", line)\n        if !isnothing(m)\n            nchannels = parse(Int, m.captures[1])\n        end\n\n        m = match(r\"\\s+[\\de\\-\\.]+\\s+([\\d\\.\\-]+)\\s+\", line)\n        if !isnothing(m)\n            bit = round(parse(Float64, m.captures[1]))\n            push!(s, DBit(bit))\n        end\n    end\n\n    return s, samplerate, nchannels\nend\n\nfunction writedat(filename, s::DBitstream; samplerate, nchannels)\n    open(filename, \"w\") do io\n        write(io, \"; Sample Rate $samplerate\\n\")\n        write(io, \"; Channels $nchannels\\n\")\n        for i in 1:length(s)\n            bit = pop!(s)\n            write(io, \" $((i - 1) * (1 / samplerate))  $(float(bit)) \\n\")\n        end\n    end\nend\n\nsvfilter = SVFilter(0.125, 1.875, 1)\nx, samplerate, nchannels = readdat(\"./examples/Expchirp.dat\")\ny = DBitstream()\n\nfor i in 1:length(x)\n    push!(y, svfilter(pop!(x)))\nend\n\nwritedat(\"./examples/Expchirp-output.dat\", y; samplerate = samplerate, nchannels = nchannels)","category":"page"},{"location":"dbitstream-example/#","page":"Deterministic Bitstream Walkthrough","title":"Deterministic Bitstream Walkthrough","text":"Instead, we call your attention to the lines towards the end of the code block which instantiate a SVFilter, read in some audio data, then pass the audio data through the filter and store the results in an output DBitstream.","category":"page"},{"location":"getting-started/#Getting-Started-1","page":"Getting started","title":"Getting Started","text":"","category":"section"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"BitSAD allows you to perform linear algebra arithmetic with bitstreams. A bitstream is a sequence of single bit values that represents some data. There are two types of bitstreams in BitSAD — stochastic bitstream (SBitstream) and deterministic bitstreams (DBitstream).","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"Stochastic bitstreams refer to bit sequences found in stochastic computing. Such bitstreams are modeled as a Bernoulli sequence whose mean is the real number being encoded. Deterministic bitstreams refer to pulse density modulated audio data. In this case, the density of high bits is proportional to the amplitude of the audio signal.","category":"page"},{"location":"getting-started/#Creating-Bitstreams-1","page":"Getting started","title":"Creating Bitstreams","text":"","category":"section"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"Creating a bitstream variable is straightforward:","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"x = SBitstream(0.1)\ny = DBitstream()","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"Here x is a stochastic bitstream representing the real number 0.1. y is a deterministic bitstream. Deterministic bitstreams don't represent a single underlying value, so the constructor receives no arguments. Any bitstream object contains a queue of bits that holds the internal sequence of bits. Upon creation, neither x nor y have any bits in their queue. Below, in Operating on Bitstreams, you will see how to add bits to their queues.","category":"page"},{"location":"getting-started/#Operating-on-Bitstreams-1","page":"Getting started","title":"Operating on Bitstreams","text":"","category":"section"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"Both types of bitstreams inherit from a shared abstract type — AbstractBitstream. If you were to create your own bitstream type, you would need to inherit from this abstract type. This allows us to define some shared operations that apply to all bitstreams. For example, we can push and pop bits from bitstreams:","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"x = SBitstream(0.1)\ny = DBitstream()\n\npush!(y, DBit(false)) # add a low bit to y's queue\npop!(y) == DBit(false) # true\nprint(pop!(x)) # prints a randomly generated bit according to Bernoulli(0.1)\npop!(y) # ERROR!","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"In the example above, we pushed and popped a bit from y, a deterministic bitstream. You cannot pop! from an empty DBitstream. This is allowed for SBitstreams though. Since a stochastic bitstream is modeled as a Bernoulli sequence, we sample from that distribution to generate a new bit whenever the queue is empty. If you do push bits onto an SBitstream's queue, then those bits will be popped first before any new bits are generated.","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"Once there are bits in the queue (or not for SBitstreams), you can perform arithmetic:","category":"page"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"x = SBitstream(0.1)\ny = SBitstream(0.3)\n\n# this expression will pop randomly generated bits\n# from x and y, then add those bits and return\n# a new SBitstream object with the result bit\n# in its queue\nx + y","category":"page"},{"location":"getting-started/#Under-the-Hood-1","page":"Getting started","title":"Under the Hood","text":"","category":"section"},{"location":"getting-started/#","page":"Getting started","title":"Getting started","text":"What does the comment in the above example mean? In hardware, a bitstream computing program is represented by a circuit. A stream of bits enters the circuit inputs, and each bit is processed one-by-one to produce an output bitstream. So, x + y is an operator that works on single bits. We mentioned that all bitstreams have a queue containing the underlying sequence of bits. For SBitstreams, this is a sequence of SBits. The + operator is defined for SBits to add two inputs bit samples according to the hardware specification. In other words, when you run x + y, the result is computed exactly as it would be in hardware. In this way, BitSAD allows users to write programs at a high algorithmic level, simulate the hardware results, verify the results, then map the program to Verilog.","category":"page"},{"location":"sbitstream/#Stochastic-Bitstreams-1","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"","category":"section"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"An SBitstream is a stochastic bitstream representing a sequence of SBits. Each SBitstream is associated with an underlying real value.","category":"page"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"SBit\nSBitstream","category":"page"},{"location":"sbitstream/#BitSAD.SBit","page":"Stochastic Bitstreams","title":"BitSAD.SBit","text":"SBit\n\nA stochastic bit is a pair of unipolar bits (positive and negative channels).\n\nFields:\n\nbit::Tuple{Bool, Bool}: a sample of a bitstream\nvalue::Float64: the underlying floating-point number being represented\nid::UInt32: a unique identifier for all samples of this bitstream\n\n\n\n\n\n","category":"type"},{"location":"sbitstream/#BitSAD.SBitstream","page":"Stochastic Bitstreams","title":"BitSAD.SBitstream","text":"SBitstream\n\nA stochastic bitstream that represents a real (floating-point) number between [-1, 1].\n\nFields:\n\nbits::Queue{SBit}: the underlying bitstream\nvalue::Float64: the underlying floating-point number being represented\nid::UInt32: a unique identifier for this bitstream (set automatically)\n\n\n\n\n\n","category":"type"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"To represent signed numbers in -1 1, we use two single bitstreams — a positive channel and a negative channel. So, an SBit is actually a tuple of two boolean values.","category":"page"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"pos\nneg","category":"page"},{"location":"sbitstream/#BitSAD.pos","page":"Stochastic Bitstreams","title":"BitSAD.pos","text":"pos(b::SBit)\n\nReturn the positive channel bit of a stochastic bit.\n\n\n\n\n\n","category":"function"},{"location":"sbitstream/#BitSAD.neg","page":"Stochastic Bitstreams","title":"BitSAD.neg","text":"neg(b::SBit)\n\nReturn the negative channel bit of a stochastic bit.\n\n\n\n\n\n","category":"function"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"We can also access the underlying real value using float.","category":"page"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"float(b::SBit)","category":"page"},{"location":"sbitstream/#Base.float-Tuple{SBit}","page":"Stochastic Bitstreams","title":"Base.float","text":"float(b::SBit)\nfloat(s::SBitstream)\n\nReturn the underlying floating-point value of a stochastic bit or bitstream.\n\n\n\n\n\n","category":"method"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"Finally, we can fill up a SBitstream with a bit sequence using generate! and estimate the empirical average using estimate!.","category":"page"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"generate\nestimate!","category":"page"},{"location":"sbitstream/#BitSAD.generate","page":"Stochastic Bitstreams","title":"BitSAD.generate","text":"generate(s::SBitstream, T::Integer = 1)\ngenerate!(s::SBitstream, T::Integer = 1)\n\nGenerate T samples of the bitstream. Add them to its queue for generate!.\n\n\n\n\n\n","category":"function"},{"location":"sbitstream/#BitSAD.estimate!","page":"Stochastic Bitstreams","title":"BitSAD.estimate!","text":"estimate!(buffer::AbstractVector, b::SBit)\nestimate!(buffer::AbstractVector, b::VecOrMat{SBit})\nestimate!(buffer::AbstractVector)\n\nPush b into the buffer and return the current estimate.\n\n\n\n\n\n","category":"function"},{"location":"sbitstream/#Operators-1","page":"Stochastic Bitstreams","title":"Operators","text":"","category":"section"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"The following operations are defined for SBits and SBitstreams.","category":"page"},{"location":"sbitstream/#","page":"Stochastic Bitstreams","title":"Stochastic Bitstreams","text":"Operation Name Conditions\n+(x::SBit, y::SBit) Addition None\n-(x::SBit, y::SBit) Subtraction None\n*(x::SBit, y::SBit) Multiplication None\n/(x::SBit, y::SBit) Division y > 0\n÷(x::SBit, y::Real) Fixed-Gain Division y >= 1\nsqrt(x::SBit) Square Root x >= 0\nnorm(x::Vector{SBit}) L2 Norm None","category":"page"},{"location":"dbitstream/#Deterministic-Bitstreams-1","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"","category":"section"},{"location":"dbitstream/#","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"A DBitstream is a sequence of DBits representing PDM encoded audio.","category":"page"},{"location":"dbitstream/#","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"DBit\nDBitstream","category":"page"},{"location":"dbitstream/#BitSAD.DBit","page":"Deterministic Bitstreams","title":"BitSAD.DBit","text":"DBit\n\nA deterministic bit is a single bit representing ±1.\n\nFields:\n\nbit::Bool: a sample of a bitstream\n\n\n\n\n\n","category":"type"},{"location":"dbitstream/#BitSAD.DBitstream","page":"Deterministic Bitstreams","title":"BitSAD.DBitstream","text":"DBitstream\n\nA deterministic bitstream that looks like a PDM-encoded audio format.\n\nFields:\n\nbits::Queue{DBit}: the underlying bitstream\n\n\n\n\n\n","category":"type"},{"location":"dbitstream/#","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"A DBit maps 0 1 mapsto -1 1. We can access this mapping through float.","category":"page"},{"location":"dbitstream/#","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"float(b::DBit)","category":"page"},{"location":"dbitstream/#Base.float-Tuple{DBit}","page":"Deterministic Bitstreams","title":"Base.float","text":"float(b::DBit)\n\nMap b to the underlying floating-point value using 0 1 to -1 1\n\n\n\n\n\n","category":"method"},{"location":"dbitstream/#Operators-1","page":"Deterministic Bitstreams","title":"Operators","text":"","category":"section"},{"location":"dbitstream/#","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"The following operations are defined for DBits. Note that they are not defined for DBitstream.","category":"page"},{"location":"dbitstream/#","page":"Deterministic Bitstreams","title":"Deterministic Bitstreams","text":"Operation Name\n+(x::DBit, y::DBit) Addition\n+(x::DBit, y::Real) Addition\n+(x::Real, y::DBit) Addition\n-(x::DBit, y::DBit) Subtraction\n-(x::DBit, y::Real) Subtraction\n-(x::Real, y::DBit) Subtraction\n*(x::DBit, y::DBit) Multiplication\n*(x::DBit, y::Real) Multiplication\n*(x::Real, y::DBit) Multiplication\n/(x::DBit, y::DBit) Division\n/(x::DBit, y::Real) Division\n/(x::Real, y::DBit) Division","category":"page"},{"location":"#BitSAD.jl-1","page":"Home","title":"BitSAD.jl","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"BitSAD is a domain-specific language for bitstream computing. It aims to provide a general purpose linear algebra interface for writing algorithms that can be mapped to bitstream computing hardware. Programs written in BitSAD can be turned into synthesizable, verified Verilog code.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"See CITATION.bib for how to cite BitSAD if you use it in your research.","category":"page"},{"location":"#","page":"Home","title":"Home","text":"Note: Hardware generation is still being ported over to BitSAD.jl from the original Scala implementation.","category":"page"},{"location":"#Installation-1","page":"Home","title":"Installation","text":"","category":"section"},{"location":"#","page":"Home","title":"Home","text":"You can install BitSAD by opening a Julia REPL and entering:","category":"page"},{"location":"#","page":"Home","title":"Home","text":"> ] add https://github.com/UW-PHARM/BitSAD.jl","category":"page"},{"location":"bitstream/#Bitstreams-1","page":"Abstract Bitstreams","title":"Bitstreams","text":"","category":"section"},{"location":"bitstream/#","page":"Abstract Bitstreams","title":"Abstract Bitstreams","text":"All bitstreams inherit from a shared abstract type, AbstractBitstream. This type defines a bitstream as a queue (sequence) of bits. Since the underlying \"bit\" in BitSAD depends on the type of bitstream being used, we also define an abstract bit type, AbstractBit.","category":"page"},{"location":"bitstream/#","page":"Abstract Bitstreams","title":"Abstract Bitstreams","text":"AbstractBit\nAbstractBitstream","category":"page"},{"location":"bitstream/#BitSAD.AbstractBit","page":"Abstract Bitstreams","title":"BitSAD.AbstractBit","text":"AbstractBit\n\nInherit from this type to create a custom bit type.\n\n\n\n\n\n","category":"type"},{"location":"bitstream/#BitSAD.AbstractBitstream","page":"Abstract Bitstreams","title":"BitSAD.AbstractBitstream","text":"AbstractBitstream\n\nInherit from this type to create a custom bitstream type.\n\nExpected fields:\n\nbits::Queue{AbstractBit}: the underlying bitstream\n\n\n\n\n\n","category":"type"},{"location":"bitstream/#","page":"Abstract Bitstreams","title":"Abstract Bitstreams","text":"Any bitstream has several common operations defined on it.","category":"page"},{"location":"bitstream/#","page":"Abstract Bitstreams","title":"Abstract Bitstreams","text":"push!\npop!\nobserve\nlength","category":"page"},{"location":"bitstream/#Base.push!","page":"Abstract Bitstreams","title":"Base.push!","text":"push!(s::AbstractBitstream, b)\n\nPush a bit(s) b onto bitstream s.\n\nFields:\n\ns::AbstractBitstream: the bitstream object\nb: the bit(s) to push onto the stream\n\n\n\n\n\n","category":"function"},{"location":"bitstream/#Base.pop!","page":"Abstract Bitstreams","title":"Base.pop!","text":"pop!(s::AbstractBitstream)\n\nPop a bit from bitstream s.\n\nFields:\n\ns::AbstractBitstream: the bitstream object\n\n\n\n\n\n","category":"function"},{"location":"bitstream/#BitSAD.observe","page":"Abstract Bitstreams","title":"BitSAD.observe","text":"observe(s::AbstractBitstream)\n\nExamine the most recent bit added to the stream without removing it.\n\nFields:\n\ns::AbstractBitstream: the bitstream object\n\n\n\n\n\n","category":"function"},{"location":"bitstream/#Base.length","page":"Abstract Bitstreams","title":"Base.length","text":"length(s::AbstractBitstream)\n\nReturn the number of bits in s.\n\n\n\n\n\n","category":"function"},{"location":"sbitstream-example/#Walking-through-an-SBitstream-Example-1","page":"Stochastic Bitstream Walkthrough","title":"Walking through an SBitstream Example","text":"","category":"section"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Now let's walk through an SBitstream example program to compute the iterative SVD of a matrix. Here's an overview of the mathematical algorithm:","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Input: Matrix A and inital guess v_0 \n Steps: (for T iterations)","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"w_k gets Av_k - 1\nu_k gets w_k  w_k_2\nz_k gets A^top v_k - 1\nsigma_k gets z_k_2\nv_k gets z_k  sigma_k","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Return: First singular value and vectors, sigma_T u_T v_T","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"First we import BitSAD and create a module for our algorithm. There is no fixed way for defining an algorithm, but we recommend defining a struct. This way, the fields of the struct represent the submodules and internal parameters of the algorithm.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"using BitSAD\n\nstruct IterativeSVD\n    rows::Int\n    cols::Int\nend","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Above, we created the IterativeSVD module that is parameterized by the number of rows and columns in the matrix. Structs in Julia are callable, which means we can call the module like a function.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"function (dut::IterativeSVD)(A::Matrix{SBit}, v₀::Vector{SBit})\n    # Update right singular vector\n    w = A * v₀\n    wscaled = w .÷ sqrt(dut.rows)\n    u = wscaled ./ norm(wscaled)\n\n    # Update left singular vector\n    z = permutedims(A) * u\n    zscaled = z .÷ sqrt(dut.cols)\n    σ = norm(zscaled)\n    v = zscaled ./ σ\n\n    return u, v, σ\nend","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Here we defined the algorithm as accepting a matrix of SBits and a vector of SBits. Though directly operating on SBitstreams is supported, this is mostly intended for REPL-style work. If you are writing a program that you intend to map to hardware, it should operate directly on SBits. This should be intuitive — a stochastic bitstream circuit operates on a single bit at a time. In this way, you should aim for your modules to describe what happens in a single iteration. Lastly, it is also worth noting here how closely the function body matches the algorithm above.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"That's all it takes to define a bitstream computing algorithm in BitSAD. Of course, we don't just want to define the algorithm, we want to test and use it! To do that, we'll need to create some test matrices.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"using Makie, DataStructures\nusing Statistics: mean\nusing LinearAlgebra\n\nN = 10     # number of trials\nT = 20000  # length of each trial\nm = 2      # number of rows in matrix\nn = 2      # number of columns in matrix\n\n# generate inputs\nA = [2 .* rand(m, n) .- 1 for i in 1:N]\nv₀ = [rand(n) for i in 1:N]\nv₀ .= v₀ ./ norm.(v₀)\ndut = [IterativeSVD(m, n) for i in 1:N]\n\n# calculate scaling\nα = 2 .* max.(norm.(A, Inf), norm.(A, 1))\nA = A ./ α\n\n# convert to bitstream\nA = SBitstream.(A)\nv₀ = SBitstream.(v₀)","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"The code above generates an array of matrices to decompose and initial guesses. It also calculates a scaling factor to prevent the stochastic bitstreams from saturating when we run multiple iterations of the algorithm. This is an important consideration for stochastic computing, and BitSAD can allow users to empirical determine the correct scaling level. In this case, we determined theoretical scaling factors beforehand. If a bitstream variable was to saturate during computation, then BitSAD will print a warning out. In the last few lines, we take the floating-point matrices and vectors that we generated, and we create SBitstream objects out of them.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"# eval loop\nBitSAD.clearops()\nϵ = zeros(T, N)\nubuffer = [CircularBuffer{Vector{Int}}(5000) for i in 1:N]\nvbuffer = [CircularBuffer{Vector{Int}}(5000) for i in 1:N]\nσbuffer = [CircularBuffer{Int}(5000) for i in 1:N]\nThreads.@threads for trial in 1:N\n    generate!.(A[trial], T)\n    generate!.(v₀[trial], 1000)\n\n    for t in 1:T\n        # evaluate module\n        output = dut[trial](pop!.(A[trial]), pop!.(v₀[trial]))\n        (t >= 1000) && push!.(v₀[trial], decorrelate.(output[2]))\n\n        # accumulate results in buffer\n        u = estimate!(ubuffer[trial], output[1])\n        v = estimate!(vbuffer[trial], output[2])\n        σ = estimate!(σbuffer[trial], output[3])\n\n        # record loss\n        ϵ[t, trial] = norm(α[trial] * (float.(A[trial]) * v - u * σ * sqrt(n)))\n    end\n\n    println(\"Completed trial $trial\")\nend","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"The loop above is the actual test loop. The line BitSAD.clearops() resets the internal data structures utilized by BitSAD. It is not required in this case, but it can be good practice to make sure no previous operations conflict with what is about to be run. For more information on this see Internals.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"We also instantiated some CircularBuffers to keep track of the last 5000 bit samples of each output bitstream. This is not required, but we often want to keep a running windowed average of a bitstream to see if the empirical average matches the true real number the bitstream should encode.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Next, we called generate! on the matrix and vector that is the input for this trial. This will sample from the Bernoulli distribution that models each bitstream and push the samples onto their queues. Recall from Operating on Bitstreams that this is not required, but pre-generating the samples can improve performance for lengthy trials.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Finally, we enter the main loop that runs over T iterations and exercises an IterativeSVD for each step. The line dut[trial](pop.!(A[trial]), pop!.(v₀[trial])) is how we call our struct. If we weren't running for many trials, we wouldn't have multiple objects, and the call might look more like dut(pop!.(A), pop!.(v₀)). This call produces output which is the tuple returned by our algorithm. One element of this tuple, v_k, is passed back into our algorithm as an input. We can pass each returned vector or scalar SBit to the estimate! function from BitSAD. This function is a handy utility function that updates the circular buffers and returns the current empirical average. The last step of the loop body is to compute and store the current algorithm error.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"u = @. estimate!(ubuffer)\nv = @. estimate!(vbuffer)\nσ = @. estimate!(σbuffer) * sqrt(n)\nA = map(λ -> float.(λ), A)\nf = svd(A[1])\nprintln(\"u error: $(u[1] - f.U[1, :])\")\nprintln(\"v error: $(v[1] - f.V[1, :])\")\nprintln(\"σ error: $(σ[1] - f.S[1])\")\nprintln(\"  error: $(mean(norm.(α .* (A .* v .- u .* σ))))\")\nscene = lines(dropdims(mean(ϵ; dims = 2); dims = 2), color = :blue)\naxis = scene[Axis]\naxis[:names][:axisnames] = (\"Iteration #\", \"Loss\")\nscene = title(scene, \"Iterative SVD Loss Over $T Iterations\", textsize = 15)\n\nscene","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"Once the simulation is run, we can use the code above to examine the results. u = @. estimate!(ubuffer) returns the current average in the circular buffer. The rest of the code is not specific to BitSAD, instead it is just some plotting code to visualize the error over the T iterations.","category":"page"},{"location":"sbitstream-example/#Notes-and-Considerations-1","page":"Stochastic Bitstream Walkthrough","title":"Notes and Considerations","text":"","category":"section"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"The purpose of this example is not to teach you about bitstream computing or explain every function call. Rather it is walk through the high level process of designing a BitSAD program. See Bitstreams for more information on the SBitstream type and operators on them.","category":"page"},{"location":"sbitstream-example/#","page":"Stochastic Bitstream Walkthrough","title":"Stochastic Bitstream Walkthrough","text":"You may have notice we glossed over the (t >= 1000) && push!.(v₀[trial], decorrelate.(output[2])) line. Normally, we cannot directly feedback an output of a bitstream computing algorithm into its inputs. This would violate a critical assumption of stochastic computing. Instead, we pass the output through a decorrelator which is a hardware unit that creates a new i.i.d. bitstream from its input. In BitSAD, this is done by calling the decorrelate function. We then push the decorrelated bit sample onto v₀[trial]'s queue. Notice that we only do this for t >= 1000. This is for stability reasons. It allows the algorithm to receive a stable input for a 1000 iterations before we allow continuous feedback.","category":"page"}]
}