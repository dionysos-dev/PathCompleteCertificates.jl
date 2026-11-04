```@meta
CurrentModule = PathCompleteCertificates
```

# Lifts

A **lift** maps a graph to another and keeps it path-complete, so a lifted
graph needs no new check [debauche2021comparison; Def. 5](@cite). It is
**valid** for a template when the lifted graph is at least as good as the
original for that template (see [Comparing graphs](@ref))
[debauche2021comparison; Def. 6](@cite). Applying a lift is an operation on
the graph only, which solves nothing.

Lifts and their validity are established for stability. They are the steps of
[refinement](@ref "Refining the graph"), which applies them where a
certificate is tight, and the tools of [comparison](@ref "Comparing graphs"),
which uses them to prove that a graph is at least as good as another. They
fall into two categories, below, and come in dual pairs (see
[Duality](@ref)).

## Applying a lift

[`lift`](@ref)`(L, graph)` applies the lift `L` to the whole graph,
`lift(L, graph, edges)` at the given edges, and `lift(L, graph, node)` at one
node. Each lift has the forms its definition allows. The result is a
[`Lifted`](@ref): the new graph, [`get_graph`](@ref), and the
[`origins`](@ref) of its nodes, what each stands for in the old graph.

Splitting the node of the common graph, one copy per outgoing edge, gives
the dual De Bruijn graph of order 1, drawn in [Choosing a graph](@ref):

```@example
using PathCompleteCertificates
lifted = lift(OutSplitLift(), common_graph(2), 1)
n_nodes(get_graph(lifted)), origins(lifted)
```

Both new nodes are copies of node 1.

## Splits and products

Four local operations at an edge ``(s, d, i)`` are valid for every template
[athanasopoulos2019polyhedral; Defs. 4 to 7 and Thm. 1](@cite):

- the **forward product** replaces ``(s, d, i)`` by its products with the
  edges leaving ``d``, which bypasses ``d``.
- the **backward product** replaces ``(s, d, i)`` by its products with the
  edges entering ``s``, which bypasses ``s``.
- the **in-split** adds a copy ``d'`` of ``d``, with the same outgoing edges,
  and replaces ``(s, d, i)`` by ``(s, d', i)``.
- the **out-split** adds a copy ``s'`` of ``s``, with the same incoming
  edges, and replaces ``(s, d, i)`` by ``(s', d, i)``.

A split copies a node function: each copy takes the function of its node, so
every edge inequality of the new graph is one of the old ones. A product
chains two edge inequalities, which imply the inequality of their product.
So neither needs anything from the template. A split adds a node, and a
product adds none but writes a sequence of modes on an edge, which only
stability supports (see [What works with what](@ref)).

| Lift | What it does | Used by |
| :-- | :-- | :-- |
| [`OutSplitLift`](@ref) | out-splits a node at each of its outgoing edges, or at the given edges | both refinement algorithms |
| [`InSplitLift`](@ref) | in-splits a node at each of its incoming edges, or at the given edges | [`BestOfTightEdgeLifts`](@ref) |
| [`ForwardProductLift`](@ref) | the forward product at the given edges | [`BestOfTightEdgeLifts`](@ref) |
| [`BackwardProductLift`](@ref) | the backward product at the given edges | [`BestOfTightEdgeLifts`](@ref) |
| [`PathDependentLift`](@ref)`(k)` | in-splits at every edge, ``k`` times [philippe2016stability; Def. 3](@cite): from the common graph, the De Bruijn graph of order ``k`` | none |
| [`ProductLift`](@ref)`(T)` | replaces every edge by the paths of ``T`` edges [philippe2016stability; Def. 2](@cite) | none |

## Combinations and compositions

The min, max and sum lifts make a node from a set of nodes, a multiset for
the sum lift, whose function is the minimum, the maximum or the sum of theirs
[debauche2021comparison; Defs. 8 and 9](@cite). The composition lifts compose
the node functions with the dynamics [debauche2024thesis; Def. 7.58](@cite),
extended to compositions of any length by [jongeneel2025ordering](@citet).

Each is valid for the templates closed under its operation
[debauche2021comparison; Def. 7 and Thm. 3](@cite). The sum of two quadratic
forms is a quadratic form, so the sum lift is valid for the quadratic
template, but their minimum is not, so the min lift is not. A lift is also
valid when its dual lift is valid for the dual template
[debauche2024thesis; Prop. 7.5](@cite): on positive systems, the min lift is
valid for the linear copositive template, whose dual is closed under maximum
[debauche2024thesis; Thm. 7.43](@cite).
[`is_valid`](@ref)`(L, template, system)` says whether a lift is valid, and
[What works with what](@ref) lists the lifts valid for each template.

These lifts serve to compare graphs (see [Comparing graphs](@ref)).

| Lift | What it does | Used by |
| :-- | :-- | :-- |
| [`MinLift`](@ref) | a node per set of nodes, with the minimum of their functions | [`compare`](@ref) |
| [`MaxLift`](@ref) | a node per set of nodes, with the maximum of their functions | [`compare`](@ref) |
| [`SumLift`](@ref)`(T)` | a node per multiset of ``T`` nodes, with the sum of their functions. `SumLift()` stands for every ``T`` | [`compare`](@ref), with an `optimizer` |
| [`CompositionLift`](@ref)`(T)` | a node per node and sequence of ``T`` modes, composing its function with the dynamics | [`compare`](@ref), with ``T = 1`` |
| [`BackwardCompositionLift`](@ref)`(T)` | the same with the inverse dynamics | [`compare`](@ref), with ``T = 1`` |

## The identity

[`IdentityLift`](@ref) returns the graph unchanged: with it, [`compare`](@ref)
tests a plain simulation, which holds for every template.

## Adding a lift

A new lift is one file of code, in `src/lifts/catalogue/`: see
[Extending the package](@ref).
