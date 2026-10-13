"""
    BackwardSplitLift()

The [`dual`](@ref) of [`ForwardSplitLift`](@ref): copies of a node that each
leave by every outgoing edge and own part of its incoming edges. At a node it
is the backward lift of [ninite2026lifting](@cite), one copy per predecessor;
at each given edge, the partial P-lift of
[athanasopoulos2019polyhedral; Def. 6](@cite), one copy of its destination.
"""
const BackwardSplitLift = DualLift{ForwardSplitLift}

BackwardSplitLift() = DualLift(ForwardSplitLift())
