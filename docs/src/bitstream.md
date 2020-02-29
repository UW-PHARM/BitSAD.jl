# Bitstreams

All bitstreams inherit from a shared abstract type, `AbstractBitstream`. This type defines a bitstream as a queue (sequence) of bits. Since the underlying "bit" in BitSAD depends on the type of bitstream being used, we also define an abstract bit type, `AbstractBit`.

```@docs
AbstractBit
AbstractBitstream
```

Any bitstream has several common operations defined on it.

```@docs
push!
pop!
observe
length
```