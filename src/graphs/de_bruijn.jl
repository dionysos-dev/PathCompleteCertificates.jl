"""
    de_bruijn(order, n_modes)

The primal De Bruijn graph of order `order` on `n_modes` modes (Debauche,
Def. 6.10): a node per tuple of `order` modes, the last ones read, and from
`(i₁, …, iₗ)` an edge reading `σ` to `(σ, i₁, …, iₗ₋₁)`. It is complete, with
`n_modes^order` nodes, and path-complete. The dual De Bruijn graph, co-complete,
is [`dual`](@ref)`(de_bruijn(order, n_modes))`.
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
