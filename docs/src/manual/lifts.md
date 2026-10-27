```@meta
CurrentModule = PathCompleteCertificates
```

# Lifts

A **lift** turns a path-complete graph into another path-complete graph whose
best certificate is at least as good, for the templates the lift is
**valid** for ([debauche2021comparison](@cite), Def. 6): a certificate on the
graph gives one on the lifted graph, with the same value. Lifts are the steps of [refinement](@ref "Refining the graph"), which
applies them where a certificate is tight, and the tools of
[comparison](@ref "Comparing graphs"), which uses them to prove that a graph
is at least as good as another.

## Why a lift never makes the certificate worse

A lift builds the new graph from the old one, and a certificate on the new
graph from a certificate on the old one, in one of four ways:

- **Copy.** A split replaces a node by copies, and each copy takes the
  function of the node: every edge inequality of the new graph is one of the
  old ones.
- **Chain.** A product replaces an edge by its products with the edges that
  follow or precede it: two chained edge inequalities imply the inequality of
  their product ([athanasopoulos2019polyhedral](@cite)).
- **Combine.** The min, max and sum lifts make a node from a set of nodes,
  whose function is the minimum, the maximum or the sum of theirs.
- **Compose.** The composition lifts compose node functions with the
  dynamics.

Copying and chaining need nothing from the template, so they are valid for
every template. Combining and composing need a template closed under the
operation ([debauche2021comparison](@cite), Def. 7): the sum of two quadratic
forms is a quadratic form, so the sum lift is valid for the quadratic
template, but their minimum is not, so the min lift is not. A lift is also
valid when the dual template is closed under the dual operation: on positive
systems, the min lift is valid for the linear copositive template, whose dual
is closed under maximum ([debauche2024thesis](@cite), Thm. 7.43).
[`is_valid`](@ref)`(L, template, system)` says whether a lift is valid, and
[What works with what](@ref) lists the lifts valid for each template.

Every lift also keeps the graph path-complete, so a lifted graph needs no new
check.

## Applying a lift

[`lift`](@ref)`(L, graph)` applies the lift `L` to the whole graph,
`lift(L, graph, edges)` at the given edges, and `lift(L, graph, node)` at one
node; each lift supports the forms its definition gives it. The result is a
[`Lifted`](@ref): the new graph, [`graph`](@ref), and the [`origins`](@ref) of
its nodes, what each stands for in the old graph.

Splitting the node of the one-node graph, one copy per outgoing edge, gives
the dual De Bruijn graph of order 1, drawn in [Choosing a graph](@ref):

```@example
import PathCompleteCertificates as PCC
lifted = PCC.lift(PCC.OutSplitLift(), PCC.common_graph(2), 1)
PCC.n_nodes(PCC.graph(lifted)), PCC.origins(lifted)
```

Both new nodes are copies of node 1.

## The lifts

The lifts fall into the four groups above, plus the identity. Within a group,
they come in dual pairs: the out- and in-splits, the forward and backward
products, the min and max lifts, the forward and backward compositions (see
[Duality](@ref)). Refinement applies splits and products at nodes or edges;
comparison uses the identity, the combinations and the compositions.

### Splits: copying nodes

Valid for every template.

| Lift | What it does | Used by |
| :-- | :-- | :-- |
| [`OutSplitLift`](@ref) | copies a node, one copy per outgoing edge, at a node or at given edges | both refinement algorithms |
| [`InSplitLift`](@ref) | copies a node, one copy per incoming edge, at a node or at given edges | [`BestOfTightEdgeLifts`](@ref) |
| [`PathDependentLift`](@ref)`(M)` | in-splits every edge, ``M`` times: from the one-node graph, the De Bruijn graph of order ``M`` | none |

### Products: chaining edges

Valid for every template. A product writes a sequence of modes on an edge,
which stability alone supports.

| Lift | What it does | Used by |
| :-- | :-- | :-- |
| [`ForwardProductLift`](@ref) | replaces the given edges by their products with the edges that follow them | [`BestOfTightEdgeLifts`](@ref) |
| [`BackwardProductLift`](@ref) | replaces the given edges by their products with the edges that precede them | [`BestOfTightEdgeLifts`](@ref) |
| [`ProductLift`](@ref)`(T)` | replaces every edge by the paths of ``T`` edges | none |

### Combinations: minimum, maximum and sum

Valid for the templates closed under the operation.

| Lift | What it does | Used by |
| :-- | :-- | :-- |
| [`MinLift`](@ref) | a node per set of nodes, with the minimum of their functions | [`compare`](@ref), without building it |
| [`MaxLift`](@ref) | a node per set of nodes, with the maximum of their functions | [`compare`](@ref), without building it |
| [`SumLift`](@ref)`(T)` | a node per multiset of ``T`` nodes, with the sum of their functions; `SumLift()` stands for every ``T`` | [`compare`](@ref), as `SumLift()` with an `optimizer`, without building it |

### Compositions

Valid for the templates closed under composition with the matrices of the
system, for the forward lift, or with their inverses, for the backward one.

| Lift | What it does | Used by |
| :-- | :-- | :-- |
| [`CompositionLift`](@ref)`(T)` | a node per node and sequence of ``T`` modes, composing its function with the dynamics | [`compare`](@ref), with ``T = 1`` |
| [`BackwardCompositionLift`](@ref)`(T)` | the same with the inverse dynamics | [`compare`](@ref), with ``T = 1`` |

### The identity

[`IdentityLift`](@ref) returns the graph unchanged: with it, [`compare`](@ref)
tests a plain simulation, which holds for every template.

## Adding a lift

A new lift is one file: see [Extending the package](@ref).
