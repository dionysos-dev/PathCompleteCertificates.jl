"""
    DualRefinement(refinement)

The dual of a refinement, `dual(R)(G) = dual(R(dual(G)))` (Debauche,
Def. 7.4): every backward refinement is the dual of a forward one, and `dual`
of the result is the forward one again. At a locus, the edges are mapped into
the dual graph and the result mapped back.
"""
struct DualRefinement{R <: AbstractRefinement} <: AbstractRefinement
    primal::R
end

dual(refinement::AbstractRefinement) = DualRefinement(refinement)
dual(refinement::DualRefinement) = refinement.primal

scope(refinement::DualRefinement) = scope(refinement.primal)

function refine(refinement::DualRefinement, g::CertificateGraph)
    scope(refinement) isa Local && return refine(refinement, g, collect(edges(g)))

    refined = refine(refinement.primal, dual(g))
    return Refined(dual(graph(refined)), origins(refined))
end

function refine(
    refinement::DualRefinement,
    g::CertificateGraph,
    locus::AbstractVector{<:_HS.GraphTransition},
)
    dualised, dual_locus = dual(g, locus)
    refined = refine(refinement.primal, dualised, dual_locus)
    return Refined(dual(graph(refined)), origins(refined))
end
