"""
    BestOfTightEdgeLifts(lifts = (OutSplitLift(), InSplitLift(),
                                  ForwardProductLift(), BackwardProductLift()))

The procedure of [athanasopoulos2019polyhedral; Ex. 2](@cite): every lift of
`lifts` at every tight edge where it changes the graph, each candidate solved,
and the one with the lowest [`objective`](@ref) kept. Candidates with words on
their edges are left out when the problem accepts only one mode per edge.
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
    words = _accepts_words(problem(certificate))
    candidates = Lifted[]

    for edge in tight_edges(certificate; atol = atol), L in algorithm.lifts
        _changes(L, graph_, edge) || continue

        candidate = lift(L, graph_, edge)
        words || !has_words(graph(candidate)) || continue

        push!(candidates, candidate)
    end

    isempty(candidates) && return nothing

    solved = [solve(candidate) for candidate in candidates]
    best = argmin(objective.(solved))

    return candidates[best], solved[best]
end
