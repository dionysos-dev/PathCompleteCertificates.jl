"""
    language(system)

The switching sequences admitted by `system`, to pass to
[`is_path_complete`](@ref).
"""
language(system::_HS.HybridSystem) = system.automaton

is_path_complete(graph::CertificateGraph, automaton::_HS.OneStateAutomaton) =
    is_path_complete(graph, 1:_HS.ntransitions(automaton))

function is_path_complete(graph::_HS.GraphAutomaton, constraint::_HS.GraphAutomaton)
    letters = alphabet(constraint)

    # A graph reading every word reads any language over the same letters.
    (is_complete(graph, letters) || is_co_complete(graph, letters)) && return true

    index = _successors(graph)

    # Subset construction in product with the constraint: a state is a constraint
    # node and the set of graph nodes that can have read the same path.
    seen = Set{Tuple{Int, Tuple{Vararg{Int}}}}()
    pending = Tuple{Int, Set{Int}}[]

    for q in nodes(constraint)
        start = Set(nodes(graph))
        push!(seen, (q, Tuple(sort!(collect(start)))))
        push!(pending, (q, start))
    end

    while !isempty(pending)
        q, subset = pop!(pending)

        for transition in outgoing_edges(constraint, q)
            reachable = _step(index, subset, label(constraint, transition))

            isempty(reachable) && return false

            key = (dest(transition), Tuple(sort!(collect(reachable))))
            if !(key in seen)
                push!(seen, key)
                push!(pending, (dest(transition), reachable))
            end
        end
    end

    return true
end

is_path_complete(graph::WordGraph, constraint::_HS.GraphAutomaton) =
    is_path_complete(first(expanded_form(graph)), constraint)

"""
    common_graph(system)

The graph of a common Lyapunov function: one node with a loop per mode under
arbitrary switching, a copy of the constraint automaton otherwise.
"""
common_graph(system::_HS.HybridSystem) = common_graph(language(system))

function common_graph(automaton::_HS.OneStateAutomaton)
    graph = empty_graph(1)

    for mode in 1:_HS.ntransitions(automaton)
        add_edge!(graph, 1, 1, mode)
    end

    return graph
end

function common_graph(automaton::_HS.GraphAutomaton)
    graph = empty_graph(n_nodes(automaton))

    for edge in edges(automaton)
        add_edge!(graph, source(edge), dest(edge), label(automaton, edge))
    end

    return graph
end
