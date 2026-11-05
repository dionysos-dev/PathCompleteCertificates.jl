"""
    IdentityLift()

The lift that returns the graph. Its simulation proves that `H` is at least as
good as `G` for every template [philippe2019complete; Thm. 3.5](@cite).
"""
struct IdentityLift <: AbstractLift end

lift(::IdentityLift, g::CertificateGraph) = Lifted(g, collect(nodes(g)))

dual(L::IdentityLift) = L
