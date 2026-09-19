import HybridSystems

const _HS = HybridSystems

"""
    n_nodes(graph)

Return the number of nodes of a `HybridSystems.GraphAutomaton`.
"""
n_nodes(graph::_HS.GraphAutomaton) = _HS.nstates(graph)

"""
    n_edges(graph)

Return the number of transitions of `graph`.
"""
n_edges(graph::_HS.GraphAutomaton) = _HS.ntransitions(graph)

"""
    nodes(graph)

Return the nodes of `graph`.
"""
nodes(graph::_HS.GraphAutomaton) = _HS.states(graph)

"""
    edges(graph)

Return the transitions of `graph`.
"""
edges(graph::_HS.GraphAutomaton) = _HS.transitions(graph)

"""
    source(transition)

Return the source node of a graph transition.
"""
source(transition::_HS.GraphTransition) = transition.edge.src

"""
    dest(transition)

Return the destination node of a graph transition.
"""
dest(transition::_HS.GraphTransition) = transition.edge.dst

"""
    label(graph, transition)

Return the label of `transition` in `graph`.

`GraphTransition` stores the transition identifier but not its label, so the
graph is required to recover it.
"""
label(graph::_HS.GraphAutomaton, transition::_HS.GraphTransition) =
    graph.Σ[transition.edge][transition.id]

function _check_node(graph::_HS.GraphAutomaton, node::Integer)
    1 <= node <= n_nodes(graph) || throw(ArgumentError("Node $node is outside the graph."))
    return nothing
end

function outgoing_edges(graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)
    return [transition for transition in edges(graph) if source(transition) == node]
end

function incoming_edges(graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)
    return [transition for transition in edges(graph) if dest(transition) == node]
end

function outgoing_edges(graph::_HS.GraphAutomaton, node::Integer, edge_label::Integer)
    _check_node(graph, node)
    return [
        transition for transition in edges(graph) if
        source(transition) == node && label(graph, transition) == edge_label
    ]
end

function incoming_edges(graph::_HS.GraphAutomaton, node::Integer, edge_label::Integer)
    _check_node(graph, node)
    return [
        transition for transition in edges(graph) if
        dest(transition) == node && label(graph, transition) == edge_label
    ]
end

out_neighbors(graph::_HS.GraphAutomaton, node::Integer) =
    [dest(transition) for transition in outgoing_edges(graph, node)]

in_neighbors(graph::_HS.GraphAutomaton, node::Integer) =
    [source(transition) for transition in incoming_edges(graph, node)]

labels(graph::_HS.GraphAutomaton) =
    unique(label(graph, transition) for transition in edges(graph))

outgoing_labels(graph::_HS.GraphAutomaton, node::Integer) =
    unique(label(graph, transition) for transition in outgoing_edges(graph, node))

incoming_labels(graph::_HS.GraphAutomaton, node::Integer) =
    unique(label(graph, transition) for transition in incoming_edges(graph, node))

outdegree(graph::_HS.GraphAutomaton, node::Integer) = length(outgoing_edges(graph, node))
indegree(graph::_HS.GraphAutomaton, node::Integer) = length(incoming_edges(graph, node))
