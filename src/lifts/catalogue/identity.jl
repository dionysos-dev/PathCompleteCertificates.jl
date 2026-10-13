"""
    IdentityLift()

The lift that returns the graph; its simulation decides `G ≤_V H` for every
template [philippe2019complete; Thm. 3.5](@cite).
"""
struct IdentityLift <: AbstractLift end

lift(::IdentityLift, g::CertificateGraph) = Lifted(g, collect(nodes(g)))

dual(L::IdentityLift) = L
