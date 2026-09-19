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

"""
    outgoing_edges(graph, node)
    outgoing_edges(graph, node, label)

The transitions leaving `node`, optionally only those carrying `label`.
"""
function outgoing_edges(graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)
    return [transition for transition in edges(graph) if source(transition) == node]
end

"""
    incoming_edges(graph, node)
    incoming_edges(graph, node, label)

The transitions entering `node`, optionally only those carrying `label`.
"""
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

"""
    out_neighbors(graph, node)

The nodes directly reachable from `node`, one entry per transition — so a node
reachable under two labels appears twice.
"""
out_neighbors(graph::_HS.GraphAutomaton, node::Integer) =
    [dest(transition) for transition in outgoing_edges(graph, node)]

"""
    in_neighbors(graph, node)

The nodes with a transition into `node`, one entry per transition.
"""
in_neighbors(graph::_HS.GraphAutomaton, node::Integer) =
    [source(transition) for transition in incoming_edges(graph, node)]

"""
    alphabet(graph)

The distinct labels appearing on the transitions of `graph` — the switching
alphabet it can read.

This is the alphabet the graph *uses*, which is not in general the system's.
A graph that never mentions a mode has a smaller alphabet and is not
path-complete for a system that has it, so pass the system's alphabet
explicitly to [`is_path_complete`](@ref) rather than relying on this.
"""
alphabet(graph::_HS.GraphAutomaton) =
    unique(label(graph, transition) for transition in edges(graph))

"""
    outgoing_alphabet(graph, node)

The distinct labels on the transitions leaving `node` — the letters readable
from it.
"""
outgoing_alphabet(graph::_HS.GraphAutomaton, node::Integer) =
    unique(label(graph, transition) for transition in outgoing_edges(graph, node))

"""
    incoming_alphabet(graph, node)

The distinct labels on the transitions entering `node`.
"""
incoming_alphabet(graph::_HS.GraphAutomaton, node::Integer) =
    unique(label(graph, transition) for transition in incoming_edges(graph, node))

"""
    outdegree(graph, node)

The number of transitions leaving `node`.
"""
outdegree(graph::_HS.GraphAutomaton, node::Integer) = length(outgoing_edges(graph, node))
"""
    indegree(graph, node)

The number of transitions entering `node`.
"""
indegree(graph::_HS.GraphAutomaton, node::Integer) = length(incoming_edges(graph, node))
