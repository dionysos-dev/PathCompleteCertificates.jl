# A lift maps a path-complete graph to a path-complete graph (Debauche, Della
# Rossa & Jungers, Def. 5). It names no template and no problem: what it
# combines node functions with is an `Operation`, and whether that keeps the
# bound from getting worse is the template's declaration, read by `is_valid`.

"""
    AbstractLift

A transformation of a path-complete graph into another path-complete graph —
Definition 5 of Debauche, Della Rossa & Jungers, and the whole of it.

A lift is an instance, applied to a graph. Its [`scope`](@ref) says how: a
[`Global`](@ref) lift rebuilds the graph, `lift(graph)`; a [`Local`](@ref) one
acts at a locus of edges, `lift(graph, edges)`, all of them at once. Both return
a [`Lifted`](@ref), the graph with the origin of each of its nodes.

Preserving path-completeness is the soundness condition, so a certificate on
the lifted graph certifies the system whatever the template. Whether it is
guaranteed **no worse** is [`is_valid`](@ref), decided by the operations the
lift lists in [`requirements`](@ref) and the template's
[`is_closed_under`](@ref). An invalid lift returns a worse bound, never an
unsound certificate.

The four local lifts — [`ForwardEdgeSplit`](@ref), [`BackwardEdgeSplit`](@ref),
[`ForwardEdgeProduct`](@ref), [`BackwardEdgeProduct`](@ref) — require nothing;
applied at every edge they are the classical hierarchies, and applied where a
certificate is tight they are [`refine`](@ref). The global ones —
[`CompositionLift`](@ref), [`MinLift`](@ref), [`MaxLift`](@ref),
[`SumLift`](@ref) — each require one operation.
"""
abstract type AbstractLift end

"""
    Scope

How a lift is applied: [`Global`](@ref) or [`Local`](@ref). Read it with
[`scope`](@ref).
"""
abstract type Scope end

"""
    Global()

The scope of a lift applied to the whole graph, `lift(graph)`.
"""
struct Global <: Scope end

"""
    Local()

The scope of a lift applied at a locus, `lift(graph, edges)`: one edge, several,
or `edges(graph)` for all of them, simultaneously.
"""
struct Local <: Scope end

"""
    scope(lift) -> Scope

Whether `lift` is applied to the whole graph or at a locus of edges. Every lift
implements it; a strategy reads it to know what to enumerate.
"""
function scope end

"""
    Lifted(graph, origins)

What a lift returns: the lifted `graph` and, for each of its nodes, where it
came from.

`origins[node]` is the node of the original graph a copy was made of, the
vector of original nodes a subset node stands for, or a `(node, word)` pair for
a node of the composition lift. [`reindex`](@ref) reads it to carry a template's
per-node data across; a [`RefinementTrace`](@ref) keeps it so a run's lifts can
be read back.
"""
struct Lifted{G <: CertificateGraph, O}
    graph::G
    origins::Vector{O}
end

graph(lifted::Lifted) = lifted.graph

"""
    origins(lifted)

Where each node of a [`Lifted`](@ref) graph came from.
"""
origins(lifted::Lifted) = lifted.origins

"""
    requirements(lift) -> Tuple

The [`Operation`](@ref)s `lift` combines node functions with — what a template
must be closed under for the lift to be valid on it. Empty for the local lifts,
whose copies inherit their origin's function and whose products chain two
inequalities, which no template can fail to allow.
"""
requirements(::AbstractLift) = ()

"""
    is_valid(lift, template, system) -> Bool

Whether `lift` is guaranteed not to make the bound worse for `template` on
`system` — Definition 6 of Debauche, Della Rossa & Jungers: whether
``G ≤_V L(G)`` for every path-complete ``G``.

Written once: the template is closed under every operation the lift requires
([`requirements`](@ref), [`is_closed_under`](@ref)). A few methods override it
where the literature proves validity without closure, and say which theorem.

`false` never means unsound. Every lift preserves path-completeness, so a
certificate on the lifted graph certifies the system regardless; it only
carries no guarantee of improvement.
"""
function is_valid(lift::AbstractLift, template, system)
    return all(op -> is_closed_under(template, op, system), requirements(lift))
end

(lift::AbstractLift)(graph::CertificateGraph, edge::_HS.GraphTransition) =
    lift(graph, [edge])

# The edges of a locus must belong to the graph.
function _check_locus(graph::CertificateGraph, locus::AbstractVector{<:_HS.GraphTransition})
    isempty(locus) && throw(ArgumentError("the locus is empty"))
    automaton = _automaton(graph)

    for edge in locus
        _HS.has_transition(automaton, edge) ||
            throw(ArgumentError("the locus contains an edge that is not in the graph"))
    end

    return nothing
end
