"""
    AbstractRefinement

A transformation of a path-complete graph into a path-complete graph that is
guaranteed no worse for every template: a copy inherits its origin's function,
a product chains two edge inequalities (Athanasopoulos & Jungers, Thm. 1;
Ninite & Jungers, Thm. 3). Applied where a certificate is tight it is the step
of [`refine`](@ref); applied everywhere it is one of the classical hierarchies.

A refinement is an instance, applied by [`refine`](@ref): a local one at a
locus of edges, `refine(refinement, graph, edges)`, or at every edge when none
is given; a global one to the whole graph, `refine(refinement, graph)`. Both
return a [`Refined`](@ref). A new refinement is one file answering `refine`.
"""
abstract type AbstractRefinement end

"""
    Refined(graph, origins)

What a refinement returns: the refined `graph` and, for each of its nodes, the
node of the original it came from. A certificate on the original, copied along
`origins`, is one on the refined graph, which is what makes a refinement valid
for every template (Debauche, Della Rossa & Jungers, Def. 6(c)).
[`reindex`](@ref) reads it to carry per-node template data across, and a
[`RefinementTrace`](@ref) keeps it.
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
    refine(refinement, graph, edges) -> Refined
    refine(refinement, graph) -> Refined

Apply one refinement: at a locus of edges for a local one, to the whole graph
for a global one. A local refinement given no locus is applied at every edge.
The iterated form, driven by a certificate, is `refine(template, graph,
problem)`.
"""
function refine end

refine(refinement::AbstractRefinement, g::CertificateGraph, edge::_HS.GraphTransition) =
    refine(refinement, g, [edge])

refine(refinement::AbstractRefinement, g::CertificateGraph) =
    refine(refinement, g, collect(edges(g)))

function _check_locus(g::CertificateGraph, locus::AbstractVector{<:_HS.GraphTransition})
    isempty(locus) && throw(ArgumentError("the locus is empty"))
    allunique(locus) || throw(ArgumentError("the locus lists an edge twice"))
    all(edge -> has_edge(g, edge), locus) ||
        throw(ArgumentError("the locus contains an edge that is not in the graph"))
    return nothing
end
