"""
    BackwardProductLift()

Replace each given edge `(s, d, w)` by the edges `(s′, d, u·w)` for every
edge `(s′, s, u)`: the partial T\\*-lift of
[athanasopoulos2019polyhedral; Def. 5](@cite), the [`dual`](@ref) of
[`ForwardProductLift`](@ref).
"""
const BackwardProductLift = DualLift{ForwardProductLift}

BackwardProductLift() = DualLift(ForwardProductLift())
