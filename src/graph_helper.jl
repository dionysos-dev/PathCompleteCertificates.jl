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

"""
    is_path_complete(graph)
    is_path_complete(graph, alphabet)

Whether every node of `graph` has an outgoing edge for every letter of
`alphabet` — the condition under which every switching sequence is readable as
a path, and therefore the condition under which the edge inequalities certify
anything at all.

This is *not* graph-theoretic completeness, where every pair of vertices is
adjacent. Different property, hence the name.

`alphabet` defaults to the labels `graph` happens to use, which answers the
weaker question. A graph that never mentions a mode is trivially complete for
its own labels and **not** path-complete for a system that has that mode, so
pass the system's alphabet whenever the question is about a certificate.
"""
is_path_complete(graph::_HS.GraphAutomaton) = is_path_complete(graph, labels(graph))

function is_path_complete(graph::_HS.GraphAutomaton, alphabet)
    return all(
        !isempty(outgoing_edges(graph, node, edge_label)) for
        node in nodes(graph), edge_label in alphabet
    )
end

"""
    is_co_path_complete(graph)
    is_co_path_complete(graph, alphabet)

The dual of [`is_path_complete`](@ref): every node has an *incoming* edge for
every letter of `alphabet`. The dual De Bruijn graph is co-path-complete, and
its certificates aggregate with a maximum rather than a minimum.
"""
is_co_path_complete(graph::_HS.GraphAutomaton) = is_co_path_complete(graph, labels(graph))

function is_co_path_complete(graph::_HS.GraphAutomaton, alphabet)
    return all(
        !isempty(incoming_edges(graph, node, edge_label)) for
        node in nodes(graph), edge_label in alphabet
    )
end

"""
    _check_path_complete(graph, n_modes)

Throw unless `graph` certifies something for a system with `n_modes` modes.

Called by every problem's data check: path-completeness is the soundness
condition, so a graph that fails it must not reach a solver. Both orientations
are accepted — [`common`](@ref) aggregates a complete graph with a minimum and
a co-complete one with a maximum.
"""
function _check_path_complete(graph::_HS.GraphAutomaton, n_modes::Integer)
    alphabet = 1:n_modes

    is_path_complete(graph, alphabet) ||
        is_co_path_complete(graph, alphabet) ||
        throw(
            ArgumentError(
                "the graph is neither path-complete nor co-path-complete for the " *
                "system's $n_modes modes, so its edge inequalities certify nothing; " *
                "the graph uses labels $(sort(collect(labels(graph))))",
            ),
        )

    return nothing
end
