# Path-completeness (Definition II.1 of Philippe, Athanasopoulos, Angeli &
# Jungers) and the two structural conditions that are sufficient for it
# (Definition III.2). Keep the distinction: III.2 is not II.1.

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
