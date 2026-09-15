"""
    Edge

A directed edge from `source` to `target`, associated with a `label`.
"""
struct Edge
    source::Int
    target::Int
    label::Int
end

"""
    Graph

A directed labeled graph with `n_nodes` nodes and a collection of edges.

Nodes are indexed from `1` to `n_nodes`.
"""
struct Graph
    n_nodes::Int
    edges::Vector{Edge}
end

"""
    Graph(n_nodes, edges)

Construct a directed labeled graph with `n_nodes` nodes.

Each edge is specified as a tuple `(source, target, label)`.
"""
function Graph(n_nodes::Integer, edges::Vector{<:Tuple{Int, Int, Int}})
    n_nodes > 0 || throw(ArgumentError("The number of nodes must be positive."))

    converted_edges = [Edge(source, target, label) for (source, target, label) in edges]

    for edge in converted_edges
        1 <= edge.source <= n_nodes ||
            throw(ArgumentError("Edge source $(edge.source) is outside the graph."))
        1 <= edge.target <= n_nodes ||
            throw(ArgumentError("Edge target $(edge.target) is outside the graph."))
    end

    return Graph(Int(n_nodes), converted_edges)
end

# ------------------------------------------------------------------
# Basic graph information
# ------------------------------------------------------------------

"""
    n_nodes(graph)

Return the number of nodes of `graph`.
"""
n_nodes(graph::Graph) = graph.n_nodes

"""
    n_edges(graph)

Return the number of edges of `graph`.
"""
n_edges(graph::Graph) = length(graph.edges)

"""
    nodes(graph)

Return the nodes of `graph`.
"""
nodes(graph::Graph) = 1:graph.n_nodes

"""
    edges(graph)

Return the edges of `graph`.
"""
edges(graph::Graph) = graph.edges

# ------------------------------------------------------------------
# Edge information
# ------------------------------------------------------------------

"""
    source(edge)

Return the source node of `edge`.
"""
source(edge::Edge) = edge.source

"""
    target(edge)

Return the target node of `edge`.
"""
target(edge::Edge) = edge.target

"""
    label(edge)

Return the label associated with `edge`.
"""
label(edge::Edge) = edge.label

# ------------------------------------------------------------------
# Neighborhood queries
# ------------------------------------------------------------------

"""
    outgoing_edges(graph, node)

Return all edges leaving `node`.
"""
function outgoing_edges(graph::Graph, node::Integer)
    1 <= node <= graph.n_nodes || throw(ArgumentError("Node $node is outside the graph."))

    return [edge for edge in graph.edges if edge.source == node]
end

"""
    incoming_edges(graph, node)

Return all edges entering `node`.
"""
function incoming_edges(graph::Graph, node::Integer)
    1 <= node <= graph.n_nodes || throw(ArgumentError("Node $node is outside the graph."))

    return [edge for edge in graph.edges if edge.target == node]
end

"""
    outgoing_edges(graph, node, label)

Return all edges leaving `node` with the specified `label`.
"""
function outgoing_edges(graph::Graph, node::Integer, edge_label::Integer)
    1 <= node <= graph.n_nodes || throw(ArgumentError("Node $node is outside the graph."))

    return [edge for edge in graph.edges if edge.source == node && edge.label == edge_label]
end

"""
    incoming_edges(graph, node, label)

Return all edges entering `node` with the specified `label`.
"""
function incoming_edges(graph::Graph, node::Integer, edge_label::Integer)
    1 <= node <= graph.n_nodes || throw(ArgumentError("Node $node is outside the graph."))

    return [edge for edge in graph.edges if edge.target == node && edge.label == edge_label]
end

"""
    out_neighbors(graph, node)

Return the nodes directly reachable from `node`.
"""
function out_neighbors(graph::Graph, node::Integer)
    return [edge.target for edge in outgoing_edges(graph, node)]
end

"""
    in_neighbors(graph, node)

Return the nodes with an edge pointing to `node`.
"""
function in_neighbors(graph::Graph, node::Integer)
    return [edge.source for edge in incoming_edges(graph, node)]
end

# ------------------------------------------------------------------
# Labels
# ------------------------------------------------------------------

"""
    labels(graph)

Return the distinct labels appearing on the edges of `graph`.
"""
function labels(graph::Graph)
    return unique(edge.label for edge in graph.edges)
end

"""
    outgoing_labels(graph, node)

Return the distinct labels of the edges leaving `node`.
"""
function outgoing_labels(graph::Graph, node::Integer)
    return unique(edge.label for edge in outgoing_edges(graph, node))
end

"""
    incoming_labels(graph, node)

Return the distinct labels of the edges entering `node`.
"""
function incoming_labels(graph::Graph, node::Integer)
    return unique(edge.label for edge in incoming_edges(graph, node))
end

# ------------------------------------------------------------------
# Degree
# ------------------------------------------------------------------

"""
    outdegree(graph, node)

Return the number of edges leaving `node`.
"""
function outdegree(graph::Graph, node::Integer)
    return length(outgoing_edges(graph, node))
end

"""
    indegree(graph, node)

Return the number of edges entering `node`.
"""
function indegree(graph::Graph, node::Integer)
    return length(incoming_edges(graph, node))
end

# ------------------------------------------------------------------
# Completeness
# ------------------------------------------------------------------

"""
    is_complete(graph)

Return `true` if every node has an outgoing edge for every label
appearing in the graph.
"""
function is_complete(graph::Graph)
    graph_labels = labels(graph)

    for node in nodes(graph)
        for edge_label in graph_labels
            if isempty(outgoing_edges(graph, node, edge_label))
                return false
            end
        end
    end

    return true
end

"""
    is_co_complete(graph)

Return `true` if every node has an incoming edge for every label
appearing in the graph.
"""
function is_co_complete(graph::Graph)
    graph_labels = labels(graph)

    for node in nodes(graph)
        for edge_label in graph_labels
            if isempty(incoming_edges(graph, node, edge_label))
                return false
            end
        end
    end

    return true
end
