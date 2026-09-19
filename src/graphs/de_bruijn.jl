"""
    de_bruijn(order::Integer, n_modes::Integer; orientation::Symbol=:complete)

Construct a De Bruijn graph of order `order` over `n_modes` modes.

The nodes are indexed by tuples of length `order` with entries
in `1:n_modes`.

The keyword `orientation` determines the orientation of the edges:

- `:complete`: an edge from `(i₁, ..., iₗ)` to
  `(σ, i₁, ..., iₗ₋₁)`, labeled `σ`.
- `:co_complete`: the reverse orientation.

Returns a `HybridSystems.GraphAutomaton`.
"""
function de_bruijn(order::Integer, n_modes::Integer; orientation::Symbol = :complete)
    order >= 1 || throw(ArgumentError("The order must be positive."))

    n_modes >= 1 || throw(ArgumentError("The number of modes must be positive."))

    orientation in (:complete, :co_complete) ||
        throw(ArgumentError("Orientation must be :complete or :co_complete."))

    # Nodes are indexed by tuples of mode indices.
    tuples = collect(Iterators.product(ntuple(_ -> 1:n_modes, order)...))

    tuple_to_id = Dict(tuple => id for (id, tuple) in enumerate(tuples))

    graph_edges = Tuple{Int, Int, Int}[]

    for (id, tuple) in enumerate(tuples)
        for σ in 1:n_modes

            # Shift the tuple and append the new mode.
            tuple_to = (σ, tuple[1:(end - 1)]...)

            target_id = tuple_to_id[tuple_to]

            if orientation == :complete
                push!(graph_edges, (id, target_id, σ))
            else
                push!(graph_edges, (target_id, id, σ))
            end
        end
    end

    graph = _HS.GraphAutomaton(length(tuples))
    for (src, dst, edge_label) in graph_edges
        _HS.add_transition!(graph, src, dst, edge_label)
    end
    return graph
end
