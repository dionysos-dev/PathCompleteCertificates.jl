"""
    IdentityLift()

The lift that returns the graph. Its simulation is the plain
[`simulation`](@ref) map, which decides the order for every template and every
system (Philippe & Jungers, Thm. 3.5): when `G` simulates `H`, a certificate on
`G` read through the map is one on `H` in the same template. Requires nothing,
and is the first lift [`compare`](@ref) tries.
"""
struct IdentityLift <: AbstractLift end

lift(::IdentityLift, g::CertificateGraph) = Lifted(g, collect(nodes(g)))

simulation(::IdentityLift, G::CertificateGraph, H::CertificateGraph; optimizer = nothing) =
    simulation(G, H)
