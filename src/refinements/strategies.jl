import Random

"""
    SplitTightNode(refinement = ForwardEdgeSplit(); rng = nothing)

Apply `refinement` to the out-star of the node with the most tight outgoing
edges; no candidate when no node has two. Ties go to the node with the fewest
outgoing edges, then to the lowest-numbered one, or at random with `rng`.
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

Every refinement of `refinements` at every tight edge where it changes the
graph, as candidates; meant for `select = :best` in [`refine`](@ref).
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

`step`, a refinement or a lift, applied to the whole graph as the only
candidate. A lift throws unless it [`is_valid`](@ref) for the template on the
system.
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
