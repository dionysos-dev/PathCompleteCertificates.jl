"""
    BackwardProductLift()

Replace each given edge `(a, b, w)` by the edges `(a′, b, u·w)` for every
edge `(a′, a, u)`: the partial T\\*-lift of
[athanasopoulos2019polyhedral; Def. 5](@cite), the [`dual`](@ref) of
[`ForwardProductLift`](@ref).
"""
const BackwardProductLift = DualLift{ForwardProductLift}

BackwardProductLift() = DualLift(ForwardProductLift())

_changes(::BackwardProductLift, g::CertificateGraph, edge::_Edge) =
    indegree(g, source(edge)) >= 1
