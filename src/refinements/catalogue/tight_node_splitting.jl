"""
    TightNodeSplitting(; rng = nothing)

Algorithm 1 of [ninite2026lifting](@cite): the forward lift,
[`ForwardSplitLift`](@ref) at a node, of the node with the most tight outgoing
edges, among those with at least two. Ties go to the node with the fewest
outgoing edges, then the lowest index, or at random with `rng`. A node with a
single successor is passed over, since its forward lift is the graph itself.
No candidate is left when no node remains.

[`initial_graph`](@ref) is the dual of [`de_bruijn`](@ref)`(1, n_modes)`, as in
the experiments of [ninite2026lifting](@cite): from the one-node graph, whose
only successor is itself, the forward lift changes nothing.
"""
struct TightNodeSplitting{G <: Union{Nothing, Random.AbstractRNG}} <:
       AbstractRefinementAlgorithm
    rng::G
end

TightNodeSplitting(; rng = nothing) = TightNodeSplitting(rng)

initial_graph(::TightNodeSplitting, system) = dual(de_bruijn(1, n_modes(system)))

function next_graph(
    algorithm::TightNodeSplitting,
    certificate::AbstractCertificate;
    atol::Real,
    solve,
)
    graph_ = graph(certificate)
    subgraph = tight_subgraph(certificate; atol = atol)

    held = [outdegree(subgraph, node) for node in nodes(graph_)]
    lift_ = ForwardSplitLift()

    candidates =
        [node for node in nodes(graph_) if held[node] >= 2 && _changes(lift_, graph_, node)]
    isempty(candidates) && return nothing

    most = maximum(held[node] for node in candidates)
    filter!(node -> held[node] == most, candidates)

    cheapest = minimum(outdegree(graph_, node) for node in candidates)
    filter!(node -> outdegree(graph_, node) == cheapest, candidates)

    node = algorithm.rng === nothing ? first(candidates) : rand(algorithm.rng, candidates)

    return lift(lift_, graph_, node), nothing
end
