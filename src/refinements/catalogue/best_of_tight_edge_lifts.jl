"""
    BestOfTightEdgeLifts(lifts = (OutSplitLift(), InSplitLift(),
                                  ForwardProductLift(), BackwardProductLift()))

The procedure of [athanasopoulos2019polyhedral; Ex. 2](@cite). At each step,
every lift of `lifts` is applied at every tight edge, one edge at a time; by
default these are its partial P\\*-, P-, T- and T\\*-lifts (Defs. 7, 6, 4
and 5). Each candidate graph is solved, and the one with the lowest rate is
kept.
"""
struct BestOfTightEdgeLifts{L <: Tuple} <: AbstractRefinementAlgorithm
    lifts::L
end

BestOfTightEdgeLifts() = BestOfTightEdgeLifts((
    OutSplitLift(),
    InSplitLift(),
    ForwardProductLift(),
    BackwardProductLift(),
))

function next_graph(
    algorithm::BestOfTightEdgeLifts,
    certificate::AbstractCertificate;
    atol::Real,
    solve,
)
    graph_ = graph(certificate)
    candidates = Lifted[]

    for edge in tight_edges(certificate; atol = atol), L in algorithm.lifts
        _changes(L, graph_, edge) || continue

        push!(candidates, lift(L, graph_, edge))
    end

    isempty(candidates) && return nothing

    solved = [solve(candidate) for candidate in candidates]
    best = argmin(objective.(solved))

    return candidates[best], solved[best]
end
