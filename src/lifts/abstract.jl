# A lift maps a path-complete graph to a path-complete graph (Debauche, Della
# Rossa & Jungers, arXiv:2110.13474, Def. 5). It names no template and no
# problem, and has two consumers -- `refine`, and the ordering of two graphs --
# so it belongs to neither. `is_valid` (their Def. 6) goes here once the closure
# properties of our templates are proved.

"""
    AbstractLift

A transformation of a path-complete graph into another path-complete graph.

That is the definition and the whole of it: a lift names no template and no
problem, which is why lifts are their own directory rather than part of either
axis, or of the loop that drives them.

[`ForwardEdgeLift`](@ref) is the only inhabitant. It splits one node, so it is
applied as `lift(graph, node)`; the lifts of Debauche et al. are *global* — they
rebuild the node set from subsets or multisets — and will want a second arity,
not invented before there is one to write.

A lift is an instance, not a function: the T-sum lift carries a binary operation
and the composition lift carries the dynamics.

!!! note "A lift is sound; whether it *improves* is the template's business"
    Preserving path-completeness is the definition, and path-completeness is the
    soundness condition. What a template's closure properties decide is
    *validity*: whether the lifted graph is guaranteed no **worse**. An invalid
    lift returns a worse bound, never an unsound certificate.

    The forward lift needs no such property — each copy inherits the split node's
    function, so no two functions are combined.
"""
abstract type AbstractLift end
