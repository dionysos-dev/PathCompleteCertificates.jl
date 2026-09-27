# The node-splitting lifts of Ninite & Jungers (arXiv:2607.00637). Both are the
# transform in `abstract.jl`; only `_class` differs.

"""
    ForwardLift()

Split a node into one copy per distinct **successor**.

Two edges to the same successor under different labels land on the same copy, so
a node with one successor cannot be split — the memoryless one-node graph is the
case that bites. [`ForwardEdgeLift`](@ref) keeps them apart.
"""
struct ForwardLift <: AbstractLift end

"""
    ForwardEdgeLift()

Split a node into one copy per outgoing **edge**.

Strictly finer than [`ForwardLift`](@ref): every copy the coarse one makes is a
union of copies this one makes.
"""
struct ForwardEdgeLift <: AbstractLift end

_class(::ForwardLift, ::_HS.GraphAutomaton, edge) = dest(edge)

_class(::ForwardEdgeLift, graph::_HS.GraphAutomaton, edge) =
    (dest(edge), label(graph, edge))
