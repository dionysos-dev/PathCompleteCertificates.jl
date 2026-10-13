"""
    DualLift(L)

The dual of the lift `L`: `dual(L)(G) = dual(L(dual(G)))`, applied in the same
forms as `L`.
"""
struct DualLift{L <: AbstractLift} <: AbstractLift
    primal::L
end

dual(L::AbstractLift) = DualLift(L)
dual(L::DualLift) = L.primal

requirements(L::DualLift) = map(dual, requirements(L.primal))

# A primal applied at edges is applied at every edge, in `edges(g)` order, so that
# its copies are numbered as the edges of `g`.
function lift(L::DualLift, g::CertificateGraph)
    edge_list = collect(edges(g))
    applicable(lift, L.primal, g, edge_list) && return lift(L, g, edge_list)
    return _undual(lift(L.primal, dual(g)))
end

function lift(L::DualLift, g::CertificateGraph, edge_list::AbstractVector{<:_Edge})
    dualised, image = _dual_with_images(g)
    return _undual(lift(L.primal, dualised, [image[edge] for edge in edge_list]))
end

lift(L::DualLift, g::CertificateGraph, node::Integer) =
    _undual(lift(L.primal, dual(g), node))

_undual(lifted::Lifted) = Lifted(dual(graph(lifted)), origins(lifted))

simulation(L::DualLift, G::CertificateGraph, H::CertificateGraph; optimizer = nothing) =
    simulation(L.primal, dual(G), dual(H); optimizer)
