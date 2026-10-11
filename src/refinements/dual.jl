"""
    DualRefinement(refinement)

The dual of a local refinement, `dual(R)(G) = dual(R(dual(G)))` (Debauche,
Def. 7.4): every backward atom is the dual of a forward one, and `dual` of the
result is the forward one again. The locus is mapped into the dual graph and
the result mapped back.
"""
struct DualRefinement{R <: AbstractRefinement} <: AbstractRefinement
    primal::R
end

dual(refinement::AbstractRefinement) = DualRefinement(refinement)
dual(refinement::DualRefinement) = refinement.primal

function refine(
    refinement::DualRefinement,
    g::CertificateGraph,
    locus::AbstractVector{<:_HS.GraphTransition},
)
    dualised, dual_locus = dual(g, locus)
    refined = refine(refinement.primal, dualised, dual_locus)
    return Refined(dual(graph(refined)), origins(refined))
end
