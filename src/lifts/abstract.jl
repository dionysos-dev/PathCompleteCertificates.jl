# A lift maps a path-complete graph to a path-complete graph (Debauche, Della
# Rossa & Jungers, arXiv:2110.13474, Def. 5). It names no template and no
# problem, and has two consumers -- `refine`, and the ordering of two graphs --
# so it belongs to neither. `is_valid` (their Def. 6) goes here once the closure
# properties of our templates are proved.

"""
    AbstractLift

A transformation of a path-complete graph into another path-complete graph.

Every lift here splits one node into copies, so the interface is indexed by that
node:

```julia
copies(lift, graph, node)   # how `node`'s outgoing edges divide between copies
lift(graph, node)           # the lifted graph -- written once, for every lift
```

`copies` is the whole of such a lift. The lifts of Debauche et al. are *global* —
they rebuild the node set from subsets or multisets — and will want a second
arity, not invented before there is one to write.

A lift is an instance, not a function: the T-sum lift carries a binary operation
and the composition lift carries the dynamics.

!!! note "A lift is sound; whether it *improves* is the template's business"
    Preserving path-completeness is the definition, and path-completeness is the
    soundness condition. What a template's closure properties decide is
    *validity*: whether the lifted graph is guaranteed no **worse**. An invalid
    lift returns a worse bound, never an unsound certificate.

    The forward lifts need no such property — each copy inherits the split node's
    function, so no two functions are combined.
"""
abstract type AbstractLift end

# What separates two of `node`'s outgoing edges, and so which copy each lands on.
# The one method an inhabitant supplies; everything below is written against it.
function _class end

"""
    copies(lift, graph, node)

How `lift` would divide `node`'s outgoing edges between the copies it makes: one
entry per copy, holding the edges that copy keeps, in the order the copies appear
in the lifted graph.

Its `length` is the number of copies, so `1` means this lift cannot split this
node. Answering without building the graph is what lets [`refine`](@ref) ask
which edges a split would separate. A node with no outgoing edge returns empty —
the transform is what refuses.
"""
function copies(lift::AbstractLift, graph::_HS.GraphAutomaton, node::Integer)
    _check_node(graph, node)

    out = outgoing_edges(graph, node)
    classes = [_class(lift, graph, edge) for edge in out]

    return [
        [edge for (edge, class) in zip(out, classes) if isequal(class, key)] for
        key in unique(classes)
    ]
end

"""
    (lift::AbstractLift)(graph, node)

Apply `lift` to `node`, forwarding through.

Every edge *into* `node` is duplicated onto every copy; each copy keeps only the
outgoing edges [`copies`](@ref) assigned it. The result has
`n_nodes(graph) - 1 + length(copies(lift, graph, node))` nodes, the copies last.

The lifted graph reads the same language as `graph`, so it is path-complete
exactly when `graph` is.
"""
function (lift::AbstractLift)(graph::_HS.GraphAutomaton, node::Integer)
    groups = copies(lift, graph, node)

    isempty(groups) && throw(ArgumentError("node $node has no outgoing edge to lift"))

    kept = [n for n in nodes(graph) if n != node]
    offset = length(kept)

    lifted = _HS.GraphAutomaton(offset + length(groups))

    new_id = zeros(Int, n_nodes(graph))

    for (i, n) in enumerate(kept)
        new_id[n] = i
    end

    # Arriving at `node` now means arriving at any copy: a copy is fixed by where
    # you go next, not by where you came from.
    for edge in edges(graph)
        source(edge) == node && continue

        if dest(edge) == node
            for j in eachindex(groups)
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

    for (j, group) in enumerate(groups)
        for edge in group
            if dest(edge) == node
                for k in eachindex(groups)
                    _HS.add_transition!(lifted, offset + j, offset + k, label(graph, edge))
                end
            else
                _HS.add_transition!(
                    lifted,
                    offset + j,
                    new_id[dest(edge)],
                    label(graph, edge),
                )
            end
        end
    end

    return lifted
end
