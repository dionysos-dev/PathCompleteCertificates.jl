"""
    DualLift(L)

The dual of a lift, `dual(L)(G) = dual(L(dual(G)))` (Debauche, Def. 7.4);
`dual` of the result is `L` again. Its requirements are the duals of `L`'s, so
validity follows the operation table of [`dual`](@ref) (Prop. 7.5), and its
simulation is `L`'s on the dual graphs, since a map preserving labelled edges
still does once both graphs are reversed. [`MaxLift`](@ref) and
[`BackwardCompositionLift`](@ref) are the two here.
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
