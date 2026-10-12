"""
    BackwardEdgeSplit()

Split the destination of each edge listed: a copy of it owning that one
incoming edge and every outgoing edge (Athanasopoulos & Jungers, Def. 6, the
partial P-lift). The dual of [`ForwardEdgeSplit`](@ref); at every edge it is
[`PathDependentRefinement`](@ref)`(1)`.
"""
const BackwardEdgeSplit = DualRefinement{ForwardEdgeSplit}

BackwardEdgeSplit() = DualRefinement(ForwardEdgeSplit())
