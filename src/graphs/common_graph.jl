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
