# Where to lift next. A strategy is any callable `(certificate; atol) ->
# Vector{Lifted}`; these three are the rules of the literature.

import Random

"""
    SplitTightNode(lift = ForwardEdgeSplit(); rng = nothing)

The rule of Ninite & Jungers: split the node held at the **most** tight
outgoing edges, with `lift` on its out-star. One candidate, or none when no
node holds two — which on a letter graph is exactly the hypothesis of
[`is_jsr_exact`](@ref), so the search drying up is itself the certificate.

Ties go to the **cheapest** split — fewest outgoing edges, since the split adds
one node per edge and node count is the budget the comparison with
[`de_bruijn`](@ref) is about — and then to the lowest-numbered node, so a run is
identical on every machine and Julia version. Pass an `rng` to break the
remaining ties at random instead; seeding one does *not* make a run
reproducible across Julia versions, `rand(rng, ::Vector)` being free to sample
differently between them.
"""
struct SplitTightNode{L <: AbstractLift, R <: Union{Nothing, Random.AbstractRNG}}
    lift::L
    rng::R
end

SplitTightNode(lift::AbstractLift = ForwardEdgeSplit(); rng = nothing) =
    SplitTightNode(lift, rng)

function (strategy::SplitTightNode)(certificate::AbstractCertificate; atol::Real)
    graph_ = graph(certificate)
    subgraph = tight_subgraph(certificate; atol = atol)

    held = [outdegree(subgraph, node) for node in nodes(graph_)]

    best = maximum(held)
    best > 1 || return Lifted[]

    candidates = [node for node in nodes(graph_) if held[node] == best]
    cheapest = minimum(outdegree(graph_, node) for node in candidates)
    filter!(node -> outdegree(graph_, node) == cheapest, candidates)

    node = strategy.rng === nothing ? first(candidates) : rand(strategy.rng, candidates)

    return [strategy.lift(graph_, outgoing_edges(graph_, node))]
end

"""
    LiftTightEdges(lifts = (ForwardEdgeSplit(), BackwardEdgeSplit(),
                            ForwardEdgeProduct(), BackwardEdgeProduct()))

The rule of Athanasopoulos & Jungers: every local lift at every tight edge, as
candidates. Meant for `select = :best` in [`refine`](@ref), which solves each
and keeps the best — their Example 2 reaches stability in fifteen such steps
on a polyhedral template.

A split is proposed only where it changes the graph: a node with a single
outgoing (incoming) edge is not split along it.
"""
struct LiftTightEdges{L <: Tuple}
    lifts::L
end

LiftTightEdges() = LiftTightEdges((
    ForwardEdgeSplit(),
    BackwardEdgeSplit(),
    ForwardEdgeProduct(),
    BackwardEdgeProduct(),
))

function (strategy::LiftTightEdges)(certificate::AbstractCertificate; atol::Real)
    graph_ = graph(certificate)
    candidates = Lifted[]

    for edge in _tight_transitions(certificate; atol = atol), lift in strategy.lifts
        _changes(lift, graph_, edge) || continue
        push!(candidates, lift(graph_, edge))
    end

    return candidates
end

# Whether a local lift at this edge produces a different graph.
_changes(::ForwardEdgeSplit, graph, edge) = outdegree(graph, source(edge)) >= 2
_changes(::BackwardEdgeSplit, graph, edge) = indegree(graph, dest(edge)) >= 2
_changes(::ForwardEdgeProduct, graph, edge) = outdegree(graph, dest(edge)) >= 1
_changes(::BackwardEdgeProduct, graph, edge) = indegree(graph, source(edge)) >= 1
_changes(::AbstractLift, graph, edge) = true

"""
    Hierarchy(lift)

One candidate a step: `lift` applied to the whole graph — a global lift, or a
local one at every edge. `Hierarchy(PathDependentLift(1))` from the one-node graph
walks the De Bruijn hierarchy; `Hierarchy(CompositionLift(1))` is the
refinement of Jongeneel & Jungers.
"""
struct Hierarchy{L <: AbstractLift}
    lift::L
end

function (strategy::Hierarchy)(certificate::AbstractCertificate; atol::Real)
    graph_ = graph(certificate)

    return [
        scope(strategy.lift) isa Global ? strategy.lift(graph_) :
        strategy.lift(graph_, collect(edges(graph_))),
    ]
end
