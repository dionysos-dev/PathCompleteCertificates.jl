"""
    DualLift(L)

The dual of the lift `L`: `dual(L)(G) = dual(L(dual(G)))`.
"""
struct DualLift{L <: AbstractLift} <: AbstractLift
    primal::L
end

dual(L::AbstractLift) = DualLift(L)
dual(L::DualLift) = L.primal

requirements(L::DualLift) = map(dual, requirements(L.primal))

function lift(L::DualLift, g::CertificateGraph)
    lifted = lift(L.primal, dual(g))
    return Lifted(dual(graph(lifted)), origins(lifted))
end

simulation(L::DualLift, G::CertificateGraph, H::CertificateGraph; optimizer = nothing) =
    simulation(L.primal, dual(G), dual(H); optimizer)
