# The graph lifts of Ninite & Jungers, "Iterative graph lifting for automatic
# design of path-complete stability certificates" (arXiv:2607.00637, 2026).
#
# Pure graph transforms: nothing here reads a template or a problem, which is
# why they sit apart from `stability.jl` in this folder rather than inside it.
#
# Whether a given lift may be applied without losing soundness is a property of
# the *template* in play, never of the graph alone -- that check belongs with
# whatever calls these, not here.

"""
    forward_lift(graph, node)

Split `node` into one copy per distinct successor, forwarding through.

Every edge *into* `node` is duplicated onto every copy, and each copy keeps
only the one outgoing edge it was created for. The result has
`n_nodes(graph) - 1 + k` nodes, where `k` is the number of distinct nodes
`node` has an edge to.

This is the *node*-grained lift: two edges from `node` to the same successor
under different labels collapse onto the same copy. Use
[`forward_edge_lift`](@ref) to keep them apart.
"""
function forward_lift(graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)

    successors = unique(out_neighbors(graph, node))
    isempty(successors) && throw(ArgumentError("node $node has no outgoing edge to lift"))

    lifted = _HS.GraphAutomaton(n_nodes(graph) - 1 + length(successors))

    kept = [n for n in nodes(graph) if n != node]
    new_id = Dict(n => i for (i, n) in enumerate(kept))
    copy_id = Dict(w => length(kept) + i for (i, w) in enumerate(successors))

    for edge in edges(graph)
        α, β, σ = source(edge), dest(edge), label(graph, edge)

        if α != node && β != node
            _HS.add_transition!(lifted, new_id[α], new_id[β], σ)
        elseif α != node
            for w in successors
                _HS.add_transition!(lifted, new_id[α], copy_id[w], σ)
            end
        elseif β != node
            _HS.add_transition!(lifted, copy_id[β], new_id[β], σ)
        else
            for w in successors
                _HS.add_transition!(lifted, copy_id[node], copy_id[w], σ)
            end
        end
    end

    return lifted
end

"""
    forward_edge_lift(graph, node)

The edge-grained variant of [`forward_lift`](@ref): `node` is split into one
copy per outgoing *edge* rather than per successor, so two edges to the same
successor under different labels get separate copies.
"""
function forward_edge_lift(graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)

    out_edges = [(dest(t), label(graph, t)) for t in outgoing_edges(graph, node)]
    isempty(out_edges) && throw(ArgumentError("node $node has no outgoing edge to lift"))

    lifted = _HS.GraphAutomaton(n_nodes(graph) - 1 + length(out_edges))

    kept = [n for n in nodes(graph) if n != node]
    new_id = Dict(n => i for (i, n) in enumerate(kept))
    copy_id = Dict(pair => length(kept) + i for (i, pair) in enumerate(out_edges))

    for edge in edges(graph)
        α, β, σ = source(edge), dest(edge), label(graph, edge)

        if α != node && β != node
            _HS.add_transition!(lifted, new_id[α], new_id[β], σ)
        elseif α != node
            for pair in out_edges
                _HS.add_transition!(lifted, new_id[α], copy_id[pair], σ)
            end
        elseif β != node
            _HS.add_transition!(lifted, copy_id[(β, σ)], new_id[β], σ)
        else
            for pair in out_edges
                _HS.add_transition!(lifted, copy_id[(node, σ)], copy_id[pair], σ)
            end
        end
    end

    return lifted
end
