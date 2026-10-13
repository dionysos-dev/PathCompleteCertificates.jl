"""
    BackwardCompositionLift(T)

The `T`-backward composition lift, the [`dual`](@ref) of
[`CompositionLift`](@ref)`(T)`. Requires [`InverseComposition`](@ref).
"""
const BackwardCompositionLift = DualLift{CompositionLift}

BackwardCompositionLift(length::Integer) = DualLift(CompositionLift(length))
