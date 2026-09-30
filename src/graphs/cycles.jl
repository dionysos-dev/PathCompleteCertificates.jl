# Simple cycles of a labelled graph. Pure graph work, and a foundation rather
# than a feature: a cycle is what turns a certificate's *upper* bound on the
# joint spectral radius into a two-sided one, because every cycle carries a
# lower bound (Ninite & Jungers, arXiv:2607.00637, Lemma 1).
#
# Enumeration is exponential in the worst case -- a graph can have
# exponentially many simple cycles -- so the search is bounded by length.
# Soundness does not depend on finding them all: each cycle is a valid bound on
# its own, so a truncated search gives a weaker bound, never a wrong one.

"""
    simple_cycles(graph; max_length = n_nodes(graph))

Every simple cycle of `graph` of at most `max_length` edges, each as the
sequence of transitions traversed.

*Simple* means no node is visited twice, so a cycle of `k` edges passes through
`k` distinct nodes. Each is returned once, written from its lowest-numbered
node — the same cycle is not repeated in its `k` rotations.

!!! warning "Exponential in the worst case"
    A graph can have exponentially many simple cycles, and `max_length` is the
    only guard. Whoever consumes these should be sound under a *truncated*
    enumeration — reading one cycle as evidence on its own, rather than the set
    as a complete answer.
"""
function simple_cycles(graph::_HS.GraphAutomaton; max_length::Integer = n_nodes(graph))
    max_length > 0 || throw(ArgumentError("max_length must be positive"))

    cycles = Vector{Vector{_HS.GraphTransition}}()
    path = _HS.GraphTransition[]
    on_path = falses(n_nodes(graph))

    for start in nodes(graph)
        _extend_cycles!(cycles, graph, start, start, path, on_path, max_length)
    end

    return cycles
end

# Depth-first from `start`, visiting only nodes above it. Restricting to
# `next > start` is what makes each cycle appear once: a cycle is enumerated
# only on the pass that begins at its smallest node.
function _extend_cycles!(
    cycles::Vector{Vector{_HS.GraphTransition}},
    graph::_HS.GraphAutomaton,
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
