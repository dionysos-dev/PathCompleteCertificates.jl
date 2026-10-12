"""
    DualRefinement(refinement)

The dual of a refinement, `dual(R)(G) = dual(R(dual(G)))` (Debauche,
Def. 7.4): every backward atom is the dual of a forward one, and `dual` of the
result is the forward one again. The edges given are mapped into the dual graph
and the result mapped back; a global refinement is applied to the dual graph
whole, so
`dual(PathDependentRefinement(k))` from the one-node graph is the dual De
Bruijn graph.
"""
struct DualRefinement{R <: AbstractRefinement} <: AbstractRefinement
    primal::R
end

dual(refinement::AbstractRefinement) = DualRefinement(refinement)
dual(refinement::DualRefinement) = refinement.primal

# A local primal is applied at every edge, in the order `edges(g)` lists them,
# so that the copies are numbered as the edges of `g`; a global one, which
# takes no edges, is applied to the dual graph whole.
function refine(refinement::DualRefinement, g::CertificateGraph)
    primal = refinement.primal
    dualised, images = dual(g, collect(edges(g)))

    refined = if applicable(refine, primal, dualised, images)
        refine(primal, dualised, images)
    else
        refine(primal, dualised)
    end

    return Refined(dual(graph(refined)), origins(refined))
end

function refine(
    refinement::DualRefinement,
    g::CertificateGraph,
    selected::AbstractVector{<:_HS.GraphTransition},
)
    dualised, images = dual(g, selected)
    refined = refine(refinement.primal, dualised, images)
    return Refined(dual(graph(refined)), origins(refined))
end
