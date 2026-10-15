```@meta
CurrentModule = PathCompleteCertificates
```

# Graph comparison via lifts

Given two path-complete graphs ``G`` and ``H``, we say that ``H`` is at least
as good as ``G`` for a template ``\mathcal V``, written ``G \le_{\mathcal V} H``,
if every switched system admitting a certificate on ``G`` with functions in
``\mathcal V`` also admits one on ``H`` with the same template. In particular,
any bound on the joint spectral radius obtained with ``G`` can also be obtained
with ``H`` ([debauche2021comparison](@cite), Def. 4).

This order depends on the template. When the template is closed under an
operation, the order is characterised by a simulation of ``H`` by a
transformation of ``G``, the **lift** of that operation. [`compare`](@ref)
tests every lift, and the closures of a template determine which of the results
hold for it. [Comparing graphs: five graphs, three templates](@ref) does this
on the five graphs of [debauche2023ordering](@cite).

The theory is stated for arbitrary switching. A simulation found by
[`compare`](@ref) depends on the graphs only, so it transfers a certificate on
``G`` to one on ``H`` for every system for which both graphs are path-complete.
The converse, that the graphs are not ordered when there is no simulation, is
proved for arbitrary switching only.

## The template-free order

``G`` **simulates** ``H`` when there is a map ``R`` from the nodes of ``H`` to
those of ``G`` with ``(R(a), R(b), i)`` an edge of ``G`` for every edge
``(a, b, i)`` of ``H`` ([philippe2019complete](@cite), Def. 3.1). Read a
certificate on ``G`` through ``R`` and it is one on ``H``, in any template. The
converse holds too: ``G \le_{\mathcal V} H`` for every template exactly when
``G`` simulates ``H`` (Thm. 3.5). [`simulation`](@ref)`(G, H)` returns the
map, or `nothing`.

When no map exists, the graphs may still be ordered for a particular template;
the lifts below decide this.

## The lifts that decide the order

A [lift](@ref "Lifts") that combines node functions under an operation encodes
the inequalities those combinations inherit ([debauche2021comparison](@cite),
Defs. 5 to 9). When the lifted ``G`` simulates ``H``,
``G \le_{\mathcal V} H`` for every template closed under the operation; for the
min, max and sum lifts the converse holds as well. `simulation(lift, G, H)`
decides it, by the method in the third column. The splits add nothing here:
their [`origins`](@ref) are a simulation of the lifted graph by ``G``, so
whenever the lifted graph simulates ``H``, ``G`` does too and the identity lift
finds the order. The products give graphs with words on their edges, which
[`compare`](@ref) does not read.

| Lift | Decides ``G \le_{\mathcal V} H`` for | How | Simulation | Complete | Source |
| :-- | :-- | :-- | :-- | :-- | :-- |
| [`IdentityLift`](@ref)`()` | every template, every system | a map found by backtracking inside the relation below | a map | yes | [philippe2019complete](@cite), Thm. 3.5 |
| [`MinLift`](@ref)`()` | templates closed under `min` ¹ | the greatest simulation relation between the nodes, a map into subsets, polynomial | a relation | yes | [debauche2022necessary](@cite), Thm. 3; [debauche2024thesis](@cite), Thm. 8.1 |
| [`MaxLift`](@ref)`()` | templates closed under `max` | the same on the dual graphs | a relation | yes | [debauche2022necessary](@cite), Thm. 4; [debauche2024thesis](@cite), Thm. 8.5 |
| [`SumLift`](@ref)`()` | templates closed under `+` | a linear program over nonnegative matrices ``C`` with ``S_H C \ge K S_G`` and ``D_H C \le K D_G`` | an integer matrix | yes | [philippe2017path](@cite), Thm. IV.4; [debauche2023ordering](@cite), Thm. 2 |
| [`SumLift`](@ref)`(T)` | templates closed under `+` | the ``T``-sum lift is built and the map searched | a map into multisets | some ``T`` works whenever the program is feasible | [debauche2021comparison](@cite), Def. 8; [debauche2023ordering](@cite), Lemma 3 |
| [`CompositionLift`](@ref)`(T)` | templates closed under ``\circ A_i``, on the system given | the lift is built, ``|S| M^T`` nodes, and the map searched | a map into `(node, word)` pairs | no ² | [debauche2024thesis](@cite), Def. 7.58, Thm. 7.65 |
| [`BackwardCompositionLift`](@ref)`(T)` | templates closed under ``\circ A_i^{-1}``, invertible system | the forward one on the dual graphs | a map | no | [debauche2024thesis](@cite), Def. 7.61, Thm. 7.66 |

¹ The linear copositive norms are not closed under `min`, yet the min lift is
valid for them on positive systems ([debauche2024thesis](@cite), Thm. 7.43):
[`is_valid`](@ref) reads it through their dual, `PCC.PositiveBox`,
closed under `max`.

² Sufficient only: [jongeneel2025ordering](@cite), Ex. IV.3, exhibits two
graphs ordered for every composition-closed template that no composition lift
simulates. The composition lift can also strictly improve a graph (their
Ex. IV.4), and [`Hierarchy`](@ref) applies it as a step of [`refine`](@ref).

[`is_valid`](@ref) decides whether a lift is valid for a template from the
closures returned by [`is_closed_under`](@ref), tabulated on the
[Templates](@ref) page. A closure of one template of a dual pair is used for
both ([Duality](@ref)).

## `compare`

```julia
c = compare(G, H; templates = (SetProg.Ellipsoid(symmetric = true),), system, optimizer)
lifts(c)        # the lifts tried, in order
simulations(c)  # lift => simulation, for each lift whose lifted G simulates H
templates(c)    # the templates given for which H is proved no worse than G
```

The lifts are tried in this order: the identity lift, whose map settles the
question for every template and ends the search; the min and max lifts, by a
relation; the sum lift, by the linear program, only when an `optimizer` is
given; the two composition lifts of length one. Other lifts are passed with
`lifts`. A template is listed in `templates(c)` when some lift with a
simulation is valid for it on `system`, which is required with `templates`.

Without templates, a [`Comparison`](@ref) states that ``H`` is no worse than ``G`` for every template closed under the
[`requirements`](@ref) of each lift in [`simulations`](@ref).

## Graphs no better than a common Lyapunov function

The one-node graph, [`common_graph`](@ref) of the system, simulates every
graph, so ``G_0 \le_{\mathcal V} G`` always. The other direction,
`compare(G, common_graph(system))`, asks whether every certificate on ``G``
yields a common Lyapunov function with the same rate. For
a `min`-closed template it holds exactly when the min lift simulates the
one-node graph ([debauche2024thesis](@cite), Thm. 8.1): when some set of nodes
of ``G`` has, from each of its nodes and for each mode, an edge reading that
mode back into the set, so that the minimum of their functions is a common
function. A complete graph always has one, the whole graph
([debauche2021comparison](@cite), Prop. 3; [debauche2024thesis](@cite),
Cor. 7.53). The relation of the min lift finds the largest such set, and the
max lift asks the same of the reversed edges for `max`-closed templates.
[Comparing graphs: five graphs, three templates](@ref) shows both answers on
the five graphs.

## Under duality

``G \le_{\mathcal V} H`` holds exactly when
``\mathrm{dual}(G) \le_{\mathcal V^*} \mathrm{dual}(H)``
([debauche2024thesis](@cite), Prop. 6.27). Every backward lift is therefore
the dual of a forward one and decides its order on the dual graphs, and a
question about the dual copositive template is the same question about the
linear copositive template on the transposed system. See [Duality](@ref).
