"""
    BackwardCompositionLift(T)

The `T`-backward composition lift (Debauche, Def. 7.61), the dual of
[`CompositionLift`](@ref)`(T)` (Prop. 7.64): the node function is
``V_s ∘ A_{j_T}^{-1} ∘ ⋯ ∘ A_{j_1}^{-1}``. Valid for templates closed under
[`InverseComposition`](@ref) on invertible systems (Prop. 7.63); its
simulation is sufficient for the order on them (Thm. 7.66).
"""
const BackwardCompositionLift = DualLift{CompositionLift}

BackwardCompositionLift(length::Integer) = DualLift(CompositionLift(length))
