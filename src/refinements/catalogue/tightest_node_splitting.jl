"""
    TightestNodeSplitting(; rng = nothing)

Algorithm 1 of [ninite2026lifting](@cite): the out-splitting,
[`OutSplitLift`](@ref) at a node, of the node with the most tight outgoing
edges, among those with at least two. When no node
has two tight outgoing edges, there is no next graph.

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
