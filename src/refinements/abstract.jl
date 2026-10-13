"""
    AbstractRefinement

A transformation of a path-complete graph into a path-complete graph that is
no worse for every template.
"""
abstract type AbstractRefinement end

"""
    Refined(graph, origins)

The refined `graph` and, for each of its nodes, the node of the original it
came from.
"""
struct Refined{G <: CertificateGraph, O}
    graph::G
    origins::Vector{O}
end

graph(refined::Refined) = refined.graph

"""
    origins(refined)

Where each node of a [`Refined`](@ref) or a [`Lifted`](@ref) graph came from.
"""
origins(refined::Refined) = refined.origins

"""
    refine(refinement, graph, edge_list) -> Refined
    refine(refinement, graph) -> Refined

Apply `refinement` at the edges of `edge_list`; without them, a local
refinement is applied at every edge and a global one to the whole graph.
"""
function refine end

refine(refinement::AbstractRefinement, g::CertificateGraph, edge::_HS.GraphTransition) =
    refine(refinement, g, [edge])

refine(refinement::AbstractRefinement, g::CertificateGraph) =
    refine(refinement, g, collect(edges(g)))

function _check_edge_list(
    g::CertificateGraph,
    edge_list::AbstractVector{<:_HS.GraphTransition},
)
    isempty(edge_list) && throw(ArgumentError("the edge list is empty"))
    allunique(edge_list) || throw(ArgumentError("the edge list repeats an edge"))
    all(edge -> has_edge(g, edge), edge_list) ||
        throw(ArgumentError("the edge list contains an edge that is not in the graph"))
    return nothing
end
