"""
    BackwardEdgeSplit()

Split the destination of each given edge into a copy owning that incoming edge
and every outgoing edge. The dual of [`ForwardEdgeSplit`](@ref).
"""
const BackwardEdgeSplit = DualRefinement{ForwardEdgeSplit}

BackwardEdgeSplit() = DualRefinement(ForwardEdgeSplit())
