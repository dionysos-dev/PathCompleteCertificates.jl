import Random

"""
    SplitTightNode(refinement = ForwardEdgeSplit(); rng = nothing)

The rule of Ninite & Jungers (Algorithm 1): split the node held at the
**most** tight outgoing edges, with `refinement` on its out-star. One
candidate, or none when no node holds two — which with one mode per edge is
exactly the hypothesis of [`is_jsr_exact`](@ref), so the search drying up is
itself the certificate.

Ties go to the **cheapest** split, the node with the fewest outgoing edges,
since the split adds one node per edge, and then to the lowest-numbered node,
so a run is deterministic. Pass an `rng` to break the remaining ties at random
instead.
"""
struct SplitTightNode{R <: AbstractRefinement, G <: Union{Nothing, Random.AbstractRNG}}
    refinement::R
    rng::G
end

SplitTightNode(refinement::AbstractRefinement = ForwardEdgeSplit(); rng = nothing) =
    SplitTightNode(refinement, rng)

function (strategy::SplitTightNode)(certificate::AbstractCertificate; atol::Real)
    graph_ = graph(certificate)
    subgraph = tight_subgraph(certificate; atol = atol)

    held = [outdegree(subgraph, node) for node in nodes(graph_)]

    best = maximum(held)
    best > 1 || return Refined[]

    candidates = [node for node in nodes(graph_) if held[node] == best]
    cheapest = minimum(outdegree(graph_, node) for node in candidates)
    filter!(node -> outdegree(graph_, node) == cheapest, candidates)

    node = strategy.rng === nothing ? first(candidates) : rand(strategy.rng, candidates)

    return [refine(strategy.refinement, graph_, outgoing_edges(graph_, node))]
end

"""
    RefineTightEdges(refinements = (ForwardEdgeSplit(), BackwardEdgeSplit(),
                                    ForwardEdgeProduct(), BackwardEdgeProduct()))

The rule of Athanasopoulos & Jungers: every local refinement at every tight
edge, as candidates. Meant for `select = :best` in [`refine`](@ref), which
solves each and keeps the best — their Example 2 reaches stability in fifteen
such steps on a polyhedral template. A split is proposed only where it changes
the graph: a node with a single outgoing (incoming) edge is not split along it.
"""
struct RefineTightEdges{R <: Tuple}
    refinements::R
end

RefineTightEdges() = RefineTightEdges((
    ForwardEdgeSplit(),
    BackwardEdgeSplit(),
    ForwardEdgeProduct(),
    BackwardEdgeProduct(),
))

function (strategy::RefineTightEdges)(certificate::AbstractCertificate; atol::Real)
    graph_ = graph(certificate)
    candidates = Refined[]

    for edge in _tight_transitions(certificate; atol = atol),
        refinement in strategy.refinements

        _changes(refinement, graph_, edge) || continue
        push!(candidates, refine(refinement, graph_, edge))
    end

    return candidates
end

_changes(::ForwardEdgeSplit, g, edge) = outdegree(g, source(edge)) >= 2
_changes(::BackwardEdgeSplit, g, edge) = indegree(g, dest(edge)) >= 2
_changes(::ForwardEdgeProduct, g, edge) = outdegree(g, dest(edge)) >= 1
_changes(::BackwardEdgeProduct, g, edge) = indegree(g, source(edge)) >= 1
_changes(::AbstractRefinement, g, edge) = true

"""
    Hierarchy(step)

One candidate a step: `step` applied to the whole graph — a global refinement,
a local one at every edge, or a lift. `Hierarchy(PathDependentRefinement(1))`
from the one-node graph walks the De Bruijn hierarchy;
`Hierarchy(CompositionLift(1))` is the refinement of Jongeneel & Jungers
(§IV-A), accepted only where the lift [`is_valid`](@ref) for the template on
the system, since an invalid one may worsen the bound.
"""
struct Hierarchy{S <: Union{AbstractRefinement, AbstractLift}}
    step::S
end

(strategy::Hierarchy{<:AbstractRefinement})(certificate::AbstractCertificate; atol::Real) =
    [refine(strategy.step, graph(certificate))]

function (strategy::Hierarchy{<:AbstractLift})(certificate::AbstractCertificate; atol::Real)
    step = strategy.step
    is_valid(step, template(certificate), problem(certificate).system) || throw(
        ArgumentError(
            "$step is not valid for $(template(certificate)) on this system: neither " *
            "the template nor its dual is closed under what the lift requires",
        ),
    )

    lifted = lift(step, graph(certificate))
    return [Refined(graph(lifted), origins(lifted))]
end
