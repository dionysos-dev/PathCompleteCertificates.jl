"""
    de_bruijn(order, n_modes)

The De Bruijn graph of order `l = order` on `n_modes` modes. It has a node per
sequence `(i₁, …, iₗ)` of the last `l` modes, newest first, and an edge labelled
`σ` from `(i₁, …, iₗ)` to `(σ, i₁, …, iₗ₋₁)`. It is complete, hence
path-complete. Order `0` is [`common_graph`](@ref). The dual De Bruijn graph is
[`dual`](@ref)`(de_bruijn(order, n_modes))`.
"""
function de_bruijn(order::Integer, n_modes::Integer)
    order >= 0 || throw(ArgumentError("the order must be nonnegative"))
    n_modes >= 1 || throw(ArgumentError("the number of modes must be positive"))

    tuples = collect(Iterators.product(ntuple(_ -> 1:n_modes, order)...))
    id = Dict(tuple => k for (k, tuple) in enumerate(tuples))

    graph = empty_graph(length(tuples))

    for (from, tuple) in enumerate(tuples), σ in 1:n_modes
        to = order == 0 ? tuple : (σ, tuple[1:(end - 1)]...)
        add_edge!(graph, from, id[to], σ)
    end

    return graph
end

"""
    common_graph(system)
    common_graph(n_modes)

The graph of a common Lyapunov function, one node with a loop per mode: the De
Bruijn graph of order `0`.
"""
common_graph(system::_HS.HybridSystem) = common_graph(n_modes(system))

common_graph(n_modes::Integer) = de_bruijn(0, n_modes)
