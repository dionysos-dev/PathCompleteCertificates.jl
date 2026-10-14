"""
    BackwardCompositionLift(T)

The `T`-backward composition lift [debauche2024thesis; Def. 7.61](@cite), the
[`dual`](@ref) of [`CompositionLift`](@ref)`(T)`. Requires
[`InverseComposition`](@ref).
"""
const BackwardCompositionLift = DualLift{CompositionLift}

BackwardCompositionLift(length::Integer) = DualLift(CompositionLift(length))
