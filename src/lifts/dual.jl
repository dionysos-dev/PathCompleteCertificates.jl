# The dual of a lift is conjugation by the dual graph (Debauche, Def. 7.4):
# every "backward" lift in the literature is the dual of a "forward" one, and
# the max lift the dual of the min lift (Lemma 7.45, Prop. 7.64). One wrapper
# replaces four implementations and the transposition bookkeeping that goes
# wrong when it is written by hand.

"""
    DualLift(lift)

The dual of a lift: `dual(L)(G) = dual(L(dual(G)))`, Definition 7.4 of
Debauche. `dual(lift)` constructs it and `dual` of the result is `lift` again.

Its [`requirements`](@ref) are the duals of the wrapped lift's, so validity
follows the operation table of [`dual`](@ref): the dual of a lift valid for
`min`-closed templates is valid for `max`-closed ones.

At a locus, the edges are mapped into the dual graph and the result mapped back;
[`origins`](@ref) are those the wrapped lift computed on the dual graph, whose
nodes are the same.
"""
struct DualLift{L <: AbstractLift} <: AbstractLift
    lift::L
end

dual(lift::AbstractLift) = DualLift(lift)
dual(lift::DualLift) = lift.lift

scope(lift::DualLift) = scope(lift.lift)
requirements(lift::DualLift) = map(dual, requirements(lift.lift))

function (lift::DualLift)(g::CertificateGraph)
    lifted = lift.lift(dual(g))
    return Lifted(dual(graph(lifted)), origins(lifted))
end

function (lift::DualLift)(g::CertificateGraph, locus::AbstractVector{<:_HS.GraphTransition})
    dualised, dual_locus = dual(g, locus)
    lifted = lift.lift(dualised, dual_locus)
    return Lifted(dual(graph(lifted)), origins(lifted))
end
