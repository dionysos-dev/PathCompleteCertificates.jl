# Every cycle gives a lower bound on the joint spectral radius.

"""
    simple_cycles(graph; max_length = n_nodes(graph))

Every simple cycle of `graph` with at most `max_length` edges, as the
sequence of its edges.
"""
function simple_cycles(graph::CertificateGraph; max_length::Integer = n_nodes(graph))
    max_length > 0 || throw(ArgumentError("max_length must be positive"))

    cycles = Vector{Vector{_HS.GraphTransition}}()
    path = _HS.GraphTransition[]
    on_path = falses(n_nodes(graph))

    for start in nodes(graph)
        _extend_cycles!(cycles, graph, start, start, path, on_path, max_length)
    end

    return cycles
end

# Depth-first from `start`; `next > start` finds each cycle once, from its
# smallest node.
function _extend_cycles!(
    cycles::Vector{Vector{_HS.GraphTransition}},
    graph::CertificateGraph,
    start::Integer,
    current::Integer,
    path::Vector{_HS.GraphTransition},
    on_path::BitVector,
    max_length::Integer,
)
    on_path[current] = true

    for edge in outgoing_edges(graph, current)
        next = dest(edge)

        if next == start
            push!(cycles, [path; edge])
        elseif next > start && !on_path[next] && length(path) + 1 < max_length
            push!(path, edge)
            _extend_cycles!(cycles, graph, start, next, path, on_path, max_length)
            pop!(path)
        end
    end

    on_path[current] = false

    return cycles
end
