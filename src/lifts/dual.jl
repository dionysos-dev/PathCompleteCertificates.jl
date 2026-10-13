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

# A primal applied at edges is applied at the images of `edges(g)`, in that order,
# so that its copies are numbered as the edges of `g`.
function lift(L::DualLift, g::CertificateGraph)
    dualised, image = _dual_with_images(g)
    edge_list = [image[edge] for edge in edges(g)]

    lifted = if applicable(lift, L.primal, dualised, edge_list)
        lift(L.primal, dualised, edge_list)
    else
        lift(L.primal, dualised)
    end

    return _undual(lifted)
end

function lift(
    L::DualLift,
    g::CertificateGraph,
    edge_list::AbstractVector{<:_HS.GraphTransition},
)
    dualised, image = _dual_with_images(g)
    return _undual(lift(L.primal, dualised, [image[edge] for edge in edge_list]))
end

lift(L::DualLift, g::CertificateGraph, node::Integer) =
    _undual(lift(L.primal, dual(g), node))

_undual(lifted::Lifted) = Lifted(dual(graph(lifted)), origins(lifted))

simulation(L::DualLift, G::CertificateGraph, H::CertificateGraph; optimizer = nothing) =
    simulation(L.primal, dual(G), dual(H); optimizer)
