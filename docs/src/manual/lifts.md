```@meta
CurrentModule = PathCompleteCertificates
```

# Lifts

A **lift** turns a path-complete graph into another path-complete graph that
gives a bound at least as good, for the templates it is valid for. Lifts are
the steps of [refinement](@ref "Refining the graph") and the tools of
[comparison](@ref "Comparing graphs").

```@example
import PathCompleteCertificates as PCC
lifted = PCC.lift(PCC.OutSplitLift(), PCC.common_graph(2), 1)
PCC.n_nodes(PCC.graph(lifted)), PCC.origins(lifted)
```

Splitting the node of the one-node graph gives two nodes, each a copy of
node 1: the dual De Bruijn graph of order 1.

## What a lift is

[`lift`](@ref)`(L, graph)` applies the lift `L` to the whole graph,
`lift(L, graph, edges)` at the given edges, and `lift(L, graph, node)` at one
node; each lift supports the forms its definition gives it. The result is a
[`Lifted`](@ref): the new graph, [`graph`](@ref), and the [`origins`](@ref) of
its nodes in the old one.

## The lifts, and who uses them

### Lifts for refinement

These lifts need nothing from the template: each copy of a node takes the
function of the node, and a product chains two edge inequalities.

| Lift | What it does | Applied at |
| :-- | :-- | :-- |
| [`OutSplitLift`](@ref) | copies a node, one copy per outgoing edge | a node, or edges |
| [`InSplitLift`](@ref) | copies a node, one copy per incoming edge | a node, or edges |
| [`ForwardProductLift`](@ref) | replaces an edge by its products with the edges that follow it | edges |
| [`BackwardProductLift`](@ref) | replaces an edge by its products with the edges that precede it | edges |

A product writes a sequence of modes on an edge, which is supported for
stability only. Two more lifts apply to the whole graph:
[`PathDependentLift`](@ref)`(M)`, which turns the one-node graph into the De
Bruijn graph of order `M`, and [`ProductLift`](@ref)`(T)`.

### Lifts for comparison

These lifts combine node functions, so they are valid only for templates
closed under the operation they use; see [Comparing graphs](@ref).

| Lift | Valid for templates closed under |
| :-- | :-- |
| [`IdentityLift`](@ref) | nothing: valid for every template |
| [`MinLift`](@ref) | pointwise minimum |
| [`MaxLift`](@ref) | pointwise maximum |
| [`SumLift`](@ref) | addition |
| [`CompositionLift`](@ref) | composition with the dynamics |
| [`BackwardCompositionLift`](@ref) | composition with the inverse dynamics |

## Adding a lift

A new lift is one file: see [Extending the package](@ref).
