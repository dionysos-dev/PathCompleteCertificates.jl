"""
    de_bruijn(order::Integer, n_modes::Integer; orientation::Symbol=:complete)

Construct a De Bruijn graph of order `order` over `n_modes` modes.

The nodes are indexed by tuples of length `order` with entries
in `1:n_modes`.

The keyword `orientation` determines the orientation of the edges:

- `:complete`: an edge from `(i₁, ..., iₗ)` to
  `(σ, i₁, ..., iₗ₋₁)`, labeled `σ`.
- `:co_complete`: the reverse orientation.

Returns a `Graph`.
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

    return Graph(length(tuples), graph_edges)
end

"""
    observer_graph(graph::Graph)

Construct the observer graph associated with `graph`.

Each observer node represents a nonempty subset of nodes
of the original graph.

The initial observer node contains all nodes of `graph`.

For each label, an observer transition maps a subset to the
set of all nodes reachable through an edge with that label.

Observer states are explored using a breadth-first search.

Returns:

- `observer`: the observer graph as a `Graph`;
- `states`: a vector of sets, where `states[i]` is the subset
  of original nodes represented by observer node `i`.

The observer graph contains only reachable nonempty subsets.
"""
function observer_graph(graph::Graph)

    ########################################################
    # Alphabet
    ########################################################

    alphabet = sort!(collect(labels(graph)))

    ########################################################
    # Adjacency dictionary
    ########################################################

    # succ[(node, label)] contains all reachable successors.
    succ = Dict{Tuple{Int, Int}, Set{Int}}()

    for edge in edges(graph)
        key = (source(edge), label(edge))
        push!(get!(succ, key, Set{Int}()), target(edge))
    end

    ########################################################
    # Observer states
    ########################################################

    initial_state = Set(nodes(graph))
    states = [initial_state]

    # Tuples of variable length are used as immutable dictionary keys.
    state_to_id = Dict{Tuple{Vararg{Int}}, Int}()
    state_to_id[Tuple(sort!(collect(initial_state)))] = 1

    graph_edges = Tuple{Int, Int, Int}[]

    # BFS queue: observer node indices.
    queue = [1]
    head = 1

    ########################################################
    # Breadth-first search
    ########################################################

    while head <= length(queue)
        id_P = queue[head]
        head += 1

        P = states[id_P]

        for σ in alphabet
            Q = Set{Int}()

            for p in P
                union!(Q, get(succ, (p, σ), Set{Int}()))
            end

            # Empty observer states are not included.
            isempty(Q) && continue

            # Canonical immutable representation of Q.
            key_Q = Tuple(sort!(collect(Q)))

            if !haskey(state_to_id, key_Q)
                id_Q = length(states) + 1

                state_to_id[key_Q] = id_Q
                push!(states, Q)
                push!(queue, id_Q)
            else
                id_Q = state_to_id[key_Q]
            end

            push!(graph_edges, (id_P, id_Q, σ))
        end
    end

    ########################################################
    # Return
    ########################################################

    observer = Graph(length(states), graph_edges)

    return observer, states
end

export de_bruijn, observer_graph
