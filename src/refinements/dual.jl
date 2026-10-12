"""
    DualRefinement(refinement)

The dual of a refinement: `dual(R)(G) = dual(R(dual(G)))`.
"""
struct DualRefinement{R <: AbstractRefinement} <: AbstractRefinement
    primal::R
end

dual(refinement::AbstractRefinement) = DualRefinement(refinement)
dual(refinement::DualRefinement) = refinement.primal

# A local primal is applied at the edges in `edges(g)` order, so copies are numbered
# as the edges of `g`.
function refine(refinement::DualRefinement, g::CertificateGraph)
    primal = refinement.primal
    dualised, edge_list = dual(g, collect(edges(g)))

    refined = if applicable(refine, primal, dualised, edge_list)
        refine(primal, dualised, edge_list)
    else
        refine(primal, dualised)
    end

    return Refined(dual(graph(refined)), origins(refined))
end

function refine(
    refinement::DualRefinement,
    g::CertificateGraph,
    edge_list::AbstractVector{<:_HS.GraphTransition},
)
    dualised, dual_edge_list = dual(g, edge_list)
    refined = refine(refinement.primal, dualised, dual_edge_list)
    return Refined(dual(graph(refined)), origins(refined))
end
