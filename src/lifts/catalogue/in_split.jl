"""
    InSplitLift()

The [`dual`](@ref) of [`OutSplitLift`](@ref): copies of a node that each
leave by every outgoing edge and own part of its incoming edges. At a node it
refines the backward lift of [ninite2026lifting](@cite), one copy per incoming
edge rather than per in-neighbour; at each given edge, the partial P-lift of
[athanasopoulos2019polyhedral; Def. 6](@cite), one copy of its destination.
"""
const InSplitLift = DualLift{OutSplitLift}

InSplitLift() = DualLift(OutSplitLift())

_changes(::InSplitLift, g::CertificateGraph, edge::_Edge) = indegree(g, dest(edge)) >= 2
