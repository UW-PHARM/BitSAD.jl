"""
    SDM

A sigma-delta modulator. Converts a floating-point value to a deterministic bit.
"""
@kwdef mutable struct SDM
    error::Float64 = 0
end

"""
    (ΣΔ::SDM)(x::Real)

Evaluate `ΣΔ` on `x` returning a `DBit`.
"""
function (ΣΔ::SDM)(x::Real)
    y = DBit(x >= ΣΔ.error)
    ΣΔ.error += float(y) - x

    return y
end