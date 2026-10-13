"""
    BestTightEdgeLifting(lifts = (ForwardSplitLift(), BackwardSplitLift(),
                                  ForwardProductLift(), BackwardProductLift()))

The procedure of [athanasopoulos2019polyhedral; Ex. 2](@cite): every lift of
`lifts` at every tight edge where it changes the graph, each candidate solved,
and the one with the lowest [`objective`](@ref) kept. Candidates with words on
their edges are left out when the problem accepts only one mode per edge.
"""
struct BestTightEdgeLifting{L <: Tuple} <: AbstractRefinementAlgorithm
    lifts::L
end

BestTightEdgeLifting() = BestTightEdgeLifting((
    ForwardSplitLift(),
    BackwardSplitLift(),
    ForwardProductLift(),
    BackwardProductLift(),
))

function next_graph(
    algorithm::BestTightEdgeLifting,
    certificate::AbstractCertificate;
    atol::Real,
    solve,
)
    graph_ = graph(certificate)
    words = _accepts_words(problem(certificate))
    candidates = Lifted[]

    for edge in _tight_transitions(certificate; atol = atol), L in algorithm.lifts
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

# Whether `L` at `edge` changes the graph: a split needs a second edge to keep
# apart, a forward product an edge to continue with.
_changes(::ForwardSplitLift, g, edge) = outdegree(g, source(edge)) >= 2
_changes(::BackwardSplitLift, g, edge) = indegree(g, dest(edge)) >= 2
_changes(::ForwardProductLift, g, edge) = outdegree(g, dest(edge)) >= 1
_changes(::BackwardProductLift, g, edge) = indegree(g, source(edge)) >= 1
_changes(::AbstractLift, g, edge) = true
