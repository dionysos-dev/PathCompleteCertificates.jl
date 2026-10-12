"""
    de_bruijn(order, n_modes)

The De Bruijn graph of order `l = order` has a node per tuple of the last `l`
modes, newest first. For all modes `i₁, …, iₗ, σ ∈ {1, …, n_modes}`, there is
an edge from `(i₁, …, iₗ)` to `(σ, i₁, …, iₗ₋₁)` with label `σ`.
Complete, hence path-complete; its dual is
[`dual`](@ref)`(de_bruijn(order, n_modes))`.
"""
function de_bruijn(order::Integer, n_modes::Integer)
    order >= 1 || throw(ArgumentError("the order must be positive"))
    n_modes >= 1 || throw(ArgumentError("the number of modes must be positive"))

    tuples = collect(Iterators.product(ntuple(_ -> 1:n_modes, order)...))
    id = Dict(tuple => k for (k, tuple) in enumerate(tuples))

    graph = empty_graph(length(tuples))

    for (from, tuple) in enumerate(tuples), σ in 1:n_modes
        add_edge!(graph, from, id[(σ, tuple[1:(end - 1)]...)], σ)
    end

    return graph
end
