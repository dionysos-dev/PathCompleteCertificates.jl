"""
    TightestNodeSplitting(; rng = nothing)

Algorithm 1 of [ninite2026lifting](@cite), with [`OutSplitLift`](@ref) at a
node, which refines their forward lift: split the node with the most tight
outgoing edges, among those with at least two, into one copy per outgoing
edge. When no node has two tight outgoing edges, there is no next graph.

Several nodes can hold as many tight edges. Among them the one with the fewest
outgoing edges is split, since its lift adds the fewest nodes; a tie that
remains goes to the lowest index, so a run is deterministic but depends on how
the nodes are numbered. With `rng`, for example `rng = MersenneTwister(1)`,
that last tie is drawn at random instead.

From [`common_graph`](@ref), the first step gives the dual of
[`de_bruijn`](@ref)`(1, n_modes)`.
"""
struct TightestNodeSplitting{R <: Union{Nothing, Random.AbstractRNG}} <:
       AbstractRefinementAlgorithm
    rng::R
end

TightestNodeSplitting(; rng = nothing) = TightestNodeSplitting(rng)

function next_graph(
    algorithm::TightestNodeSplitting,
    certificate::AbstractCertificate;
    atol::Real,
    solve,
)
    graph_ = graph(certificate)
    subgraph = tight_subgraph(certificate; atol = atol)

    held = [outdegree(subgraph, node) for node in nodes(graph_)]
    candidates = [node for node in nodes(graph_) if held[node] >= 2]
    isempty(candidates) && return nothing

    most = maximum(held[node] for node in candidates)
    filter!(node -> held[node] == most, candidates)

    cheapest = minimum(outdegree(graph_, node) for node in candidates)
    filter!(node -> outdegree(graph_, node) == cheapest, candidates)

    node = algorithm.rng === nothing ? first(candidates) : rand(algorithm.rng, candidates)

    return lift(OutSplitLift(), graph_, node), nothing
end
