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

raw"""
    is_path_complete(graph)
    is_path_complete(graph, alphabet)

Whether every finite switching sequence is readable as a path in `graph` —
Definition II.1 of Philippe, Athanasopoulos, Angeli & Jungers: for any ``k ≥ 1``
and any ``σ_1 … σ_k`` over the alphabet there is a path
``(s_i, s_{i+1}, σ_i)_{i=1..k}`` in the graph.

**This is the soundness condition.** Without it the edge inequalities certify
nothing, whatever the solver reports.

It is *not* graph-theoretic completeness, where every pair of vertices is
adjacent, and it is strictly weaker than [`is_complete`](@ref) — see that
docstring.

Decided by the subset construction: a word is readable from some node exactly
when the set of nodes reachable by it is nonempty, so the graph is
path-complete iff the subset construction started from *all* nodes never
reaches the empty set. That is a finite search, since there are finitely many
subsets.

`alphabet` defaults to the labels `graph` happens to use, which answers the
weaker question. A graph that never mentions a mode is trivially path-complete
for its own labels and **not** path-complete for a system that has that mode,
so pass the system's alphabet whenever the question is about a certificate.
"""
is_path_complete(graph::_HS.GraphAutomaton) = is_path_complete(graph, labels(graph))

function is_path_complete(graph::_HS.GraphAutomaton, alphabet)
    successors = Dict{Tuple{Int, Int}, Set{Int}}()
    for edge in edges(graph)
        key = (source(edge), label(graph, edge))
        push!(get!(successors, key, Set{Int}()), dest(edge))
    end

    # `observer_graph` runs the same search but drops empty states, which is
    # precisely the information this predicate needs, so it is repeated here.
    start = Set(nodes(graph))

    # Tuples of variable length as immutable keys, as `observer_graph` does.
    # The element type has to be written out: inferring it from the first
    # subset pins the arity, and later subsets are smaller.
    seen = Set{Tuple{Vararg{Int}}}()
    push!(seen, Tuple(sort!(collect(start))))
    pending = [start]

    while !isempty(pending)
        subset = pop!(pending)

        for letter in alphabet
            reachable = Set{Int}()
            for node in subset
                haskey(successors, (node, letter)) &&
                    union!(reachable, successors[(node, letter)])
            end

            # Some word is unreadable: the graph certifies nothing about it.
            isempty(reachable) && return false

            key = Tuple(sort!(collect(reachable)))
            if !(key in seen)
                push!(seen, key)
                push!(pending, reachable)
            end
        end
    end

    return true
end

"""
    is_complete(graph)
    is_complete(graph, alphabet)

Whether every node has an *outgoing* edge for every letter of `alphabet` —
Definition III.2 of Philippe et al.

This is **sufficient but not necessary** for [`is_path_complete`](@ref): a
graph can read every word without every node reading every letter. Use this
one only when the stronger structure is what is needed — it is what licenses
the plain minimum aggregation of Corollary III.3, which is why
[`common`](@ref) dispatches on it.
"""
is_complete(graph::_HS.GraphAutomaton) = is_complete(graph, labels(graph))

function is_complete(graph::_HS.GraphAutomaton, alphabet)
    return all(
        !isempty(outgoing_edges(graph, node, edge_label)) for
        node in nodes(graph), edge_label in alphabet
    )
end

"""
    is_co_complete(graph)
    is_co_complete(graph, alphabet)

The dual of [`is_complete`](@ref): every node has an *incoming* edge for every
letter of `alphabet`. Also sufficient but not necessary for path-completeness,
and it licenses the maximum aggregation of Corollary III.3. The dual De Bruijn
graph is co-complete.
"""
is_co_complete(graph::_HS.GraphAutomaton) = is_co_complete(graph, labels(graph))

function is_co_complete(graph::_HS.GraphAutomaton, alphabet)
    return all(
        !isempty(incoming_edges(graph, node, edge_label)) for
        node in nodes(graph), edge_label in alphabet
    )
end

"""
    _check_path_complete(graph, n_modes)

Throw unless `graph` certifies something for a system with `n_modes` modes.

Called by every problem's data check. Path-completeness is the soundness
condition, so a graph that fails it must not reach a solver — and it is the
*general* condition, so a graph that is neither complete nor co-complete is
accepted whenever it can still read every word.
"""
function _check_path_complete(graph::_HS.GraphAutomaton, n_modes::Integer)
    is_path_complete(graph, 1:n_modes) || throw(
        ArgumentError(
            "the graph is not path-complete for the system's $n_modes modes, " *
            "so its edge inequalities certify nothing; the graph uses labels " *
            "$(sort(collect(labels(graph))))",
        ),
    )

    return nothing
end
