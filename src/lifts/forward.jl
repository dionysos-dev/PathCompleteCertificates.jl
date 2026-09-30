# The node-splitting lift of Ninite & Jungers (arXiv:2607.00637), at the edge
# grain: a copy IS an outgoing edge, which is what keeps the transform short.

"""
    ForwardEdgeLift()

Split a node into one copy per outgoing edge, forwarding through.

Every edge *into* the node is duplicated onto every copy, and copy `j` keeps the
`j`-th outgoing edge and no other. The result has `n_nodes(graph) - 1 +
outdegree(graph, node)` nodes, the copies numbered last in the order
[`outgoing_edges`](@ref) lists them.

Path-completeness is preserved — the lifted graph reads exactly the same
language, since arriving at the node means arriving at whichever copy carries the
edge you leave by.

Ninite & Jungers split per distinct *successor*. That grain cannot separate two
edges to the same successor, so a node held at exactly those stays held however
often it is lifted, and the optimality certificate of [`is_jsr_exact`](@ref) —
which counts tight outgoing *edges* — is unreachable for it. Measured, it never
gives a better bound at equal node count and sometimes cannot proceed at all.
"""
struct ForwardEdgeLift <: AbstractLift end

function (::ForwardEdgeLift)(graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)

    out = outgoing_edges(graph, node)

    isempty(out) && throw(ArgumentError("node $node has no outgoing edge to lift"))

    kept = [n for n in nodes(graph) if n != node]
    offset = length(kept)

    lifted = _HS.GraphAutomaton(offset + length(out))

    new_id = zeros(Int, n_nodes(graph))

    for (i, n) in enumerate(kept)
        new_id[n] = i
    end

    # Everything that does not leave `node`. Arriving at `node` now means
    # arriving at any copy, since a copy is fixed by where you go next, not by
    # where you came from.
    for edge in edges(graph)
        source(edge) == node && continue

        if dest(edge) == node
            for j in eachindex(out)
                _HS.add_transition!(
                    lifted,
                    new_id[source(edge)],
                    offset + j,
                    label(graph, edge),
                )
            end
        else
            _HS.add_transition!(
                lifted,
                new_id[source(edge)],
                new_id[dest(edge)],
                label(graph, edge),
            )
        end
    end

    # And what leaves it: one edge per copy, which is what defines the copy.
    for (j, edge) in enumerate(out)
        if dest(edge) == node
            for k in eachindex(out)
                _HS.add_transition!(lifted, offset + j, offset + k, label(graph, edge))
            end
        else
            _HS.add_transition!(lifted, offset + j, new_id[dest(edge)], label(graph, edge))
        end
    end

    return lifted
end
