# The graph lifts of Ninite & Jungers, "Iterative graph lifting for automatic
# design of path-complete stability certificates" (arXiv:2607.00637, 2026).
#
# Pure graph transforms: nothing here reads a template or a problem, which is
# why they sit apart from `stability.jl` in this folder rather than inside it.
#
# A lift is an INSTANCE, not a function, for the same reason a template is an
# instance and not a type (CLAUDE.md section 2). The two forward lifts below
# carry nothing, so a bare function would do for them -- but the lifts of
# Debauche, Della Rossa & Jungers do not: the T-sum lift is parametrised by a
# binary operation and the composition lift by dynamics, and a function has
# nowhere to put either. The abstract type is also where `is_admissible` goes
# once the closure properties of our templates are proved (CLAUDE.md section 5);
# it is deliberately absent rather than stubbed, because a stub that answers
# `true` produces certificates that certify nothing.

"""
    AbstractLift

A transform that splits one node of a graph into several, so that a certificate
can carry a different function on each copy.

Two methods make a lift, and only the first is specific to it:

```julia
copies(lift, graph, node)   # how `node`'s outgoing edges divide between copies
lift(graph, node)           # the lifted graph -- written once, for every lift
```

`copies` is the whole of a forward lift: everything else follows from it, which
is why adding a grain is one method and not a second traversal.

!!! warning "Soundness is a property of the template, not of the graph"
    Whether a lift may be applied at all depends on the analytical properties of
    the template it will carry — closure under maximum, minimum or linear image.
    Those are proved for none of the templates here, which is why [`refine`](@ref)
    accepts one template and not an [`AbstractTemplate`](@ref). Do not widen it
    without the mathematics.
"""
abstract type AbstractLift end

"""
    ForwardLift()

Split a node into one copy per distinct **successor**, the lift of Ninite &
Jungers (2026).

Two edges from the node to the same successor under different labels land on the
same copy, so a node with one successor cannot be split at all — the memoryless
one-node graph is the case that bites. [`ForwardEdgeLift`](@ref) keeps them
apart.
"""
struct ForwardLift <: AbstractLift end

"""
    ForwardEdgeLift()

Split a node into one copy per outgoing **edge**: the finer grain, which
separates two edges to the same successor under different labels.

Not the paper's lift, and strictly more refined than [`ForwardLift`](@ref) —
every copy the coarse one makes is a union of copies this one makes.
"""
struct ForwardEdgeLift <: AbstractLift end

# What distinguishes two outgoing edges. This is the only method that differs
# between the two lifts; the transform below is shared.
_class(::ForwardLift, graph::_HS.GraphAutomaton, edge) = dest(edge)

_class(::ForwardEdgeLift, graph::_HS.GraphAutomaton, edge) =
    (dest(edge), label(graph, edge))

"""
    copies(lift, graph, node)

How `lift` would divide `node`'s outgoing edges between the copies it makes: one
entry per copy, holding the edges that copy keeps.

`length(copies(lift, graph, node))` is the number of copies, so `1` means this
lift cannot split this node, and the entries are in the order the copies appear
in the lifted graph.

Answering this without building the lifted graph is what lets a refinement loop
ask *which* edges a split would separate, rather than splitting and measuring
afterwards. A node with no outgoing edge divides into nothing, and returns empty
rather than throwing — the transform is what refuses.
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

Every edge *into* `node` is duplicated onto every copy, and each copy keeps only
the outgoing edges [`copies`](@ref) assigned to it. The result has
`n_nodes(graph) - 1 + length(copies(lift, graph, node))` nodes, and the copies
are numbered last, in the order `copies` lists them.

Path-completeness is preserved, which is the property the whole algorithm rests
on; `test/refinement/lift.jl` checks it on every lift it exercises.
"""
function (lift::AbstractLift)(graph::_HS.GraphAutomaton, node::Integer)
    groups = copies(lift, graph, node)

    isempty(groups) && throw(ArgumentError("node $node has no outgoing edge to lift"))

    kept = [n for n in nodes(graph) if n != node]
    offset = length(kept)

    lifted = _HS.GraphAutomaton(offset + length(groups))

    # Nodes are a `OneTo`, so this is an array and not a Dict (CLAUDE.md §8).
    new_id = zeros(Int, n_nodes(graph))

    for (i, n) in enumerate(kept)
        new_id[n] = i
    end

    # Everything that does not leave `node`. Arriving at `node` now means
    # arriving at any of its copies, since a copy is fixed by where you go next,
    # not by where you came from.
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

    # And what leaves it: each edge on the one copy it defines.
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
