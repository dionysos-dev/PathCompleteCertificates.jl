
"""
    observer_graph(graph::HybridSystems.GraphAutomaton)

Construct the observer graph associated with `graph`.

Each observer node represents a nonempty subset of nodes
of the original graph.

The initial observer node contains all nodes of `graph`.

For each label, an observer transition maps a subset to the
set of all nodes reachable through an edge with that label.

Observer states are explored using a breadth-first search.

Returns:

- `observer`: the observer graph as a `HybridSystems.GraphAutomaton`;
- `states`: a vector of sets, where `states[i]` is the subset
  of original nodes represented by observer node `i`.

The observer graph contains only reachable nonempty subsets.
"""
function observer_graph(graph::_HS.GraphAutomaton)

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
        key = (source(edge), label(graph, edge))
        push!(get!(succ, key, Set{Int}()), dest(edge))
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

    observer = _HS.GraphAutomaton(length(states))
    for (src, dst, edge_label) in graph_edges
        _HS.add_transition!(observer, src, dst, edge_label)
    end

    return observer, states
end
