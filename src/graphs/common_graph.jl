"""
    common_graph(system)
    common_graph(n_modes)

The graph of a common Lyapunov function: one node with a loop per mode.
"""
common_graph(system::_HS.HybridSystem) = common_graph(n_modes(system))

function common_graph(n_modes::Integer)
    n_modes >= 1 || throw(ArgumentError("the number of modes must be positive"))

    graph = empty_graph(1)

    for mode in 1:n_modes
        add_edge!(graph, 1, 1, mode)
    end

    return graph
end
