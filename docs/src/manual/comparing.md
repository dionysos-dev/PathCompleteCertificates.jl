```@meta
CurrentModule = PathCompleteCertificates
```

# Comparing graphs

Given two path-complete graphs ``G`` and ``H``, we say that ``H`` is at least
as good as ``G`` for a template ``\mathcal V``, written ``G \le_{\mathcal V} H``,
if every switched system admitting a certificate on ``G`` with functions in
``\mathcal V`` also admits one on ``H`` with the same template. In particular,
any bound on the joint spectral radius obtained with ``G`` can also be obtained
with ``H`` ([debauche2021comparison](@cite), Def. 4).

This ordering depends on the template. Under suitable closure properties it is
characterised by a simulation between a transformation of ``G``, a **lift**, and
``H``. These criteria generalise the classical simulation condition and give
procedures for deciding when one graph dominates another. The package
implements them, one per lift, and [`compare`](@ref) runs them all, reading
from the closures a template declares which verdicts apply to it.
[Comparing graphs: which one is better?](@ref) does this on the five graphs of
[debauche2023ordering](@cite).

## The template-free order

``G`` **simulates** ``H`` when there is a map ``R`` from the nodes of ``H`` to
those of ``G`` with ``(R(a), R(b), i)`` an edge of ``G`` for every edge
``(a, b, i)`` of ``H`` ([philippe2019complete](@cite), Def. 3.1). Read a
certificate on ``G`` through ``R`` and it is one on ``H``, in any template. The
converse holds too: ``G \le_{\mathcal V} H`` for every template exactly when
``G`` simulates ``H`` (Thm. 3.5). [`simulation`](@ref)`(G, H)` returns the
map, or `nothing`.

When no map exists the graphs may still be ordered for a particular template,
and that is what lifts are for.

## Lifts: one per closure

A lift replaces the nodes of ``G`` by combinations of them under one operation,
and the lifted graph encodes the inequalities those combinations inherit
([debauche2021comparison](@cite), Defs. 5 to 9). When the lifted ``G``
simulates ``H``, ``G \le_{\mathcal V} H`` for every template closed under the
operation; for the min, max and sum lifts the converse holds as well.
`simulation(lift, G, H)` decides it, and each lift does so without building
anything exponential where the theory allows.

| Lift | Decides ``G \le_{\mathcal V} H`` for | How | Simulation | Complete | Source |
| :-- | :-- | :-- | :-- | :-- | :-- |
| [`IdentityLift`](@ref)`()` | every template, every system | a labelled graph homomorphism ``H \to G``, NP-hard, searched inside the relation below | a map | yes | [philippe2019complete](@cite), Thm. 3.5 |
| [`MinLift`](@ref)`()` | templates closed under `min` ¹ | the greatest simulation relation, a map into subsets, polynomial | a relation | yes | [debauche2022necessary](@cite), Thm. 3; [debauche2024thesis](@cite), Thm. 8.1 |
| [`MaxLift`](@ref)`()` | templates closed under `max` | the same on the dual graphs | a relation | yes | [debauche2022necessary](@cite), Thm. 4; [debauche2024thesis](@cite), Thm. 8.5 |
| [`SumLift`](@ref)`()` | templates closed under `+` | a linear program over nonnegative matrices ``C`` with ``S_H C \ge K S_G`` and ``D_H C \le K D_G`` | an integer matrix | yes | [philippe2017path](@cite), Thm. IV.4; [debauche2023ordering](@cite), Thm. 2 |
| [`SumLift`](@ref)`(T)` | templates closed under `+` | the ``T``-sum lift is built and the map searched | a map into multisets | some ``T`` works whenever the program is feasible | [debauche2021comparison](@cite), Def. 8; [debauche2023ordering](@cite), Lemma 3 |
| [`CompositionLift`](@ref)`(T)` | templates closed under ``\circ A_i``, on the system given | the lift is built, ``|S| M^T`` nodes, and the map searched | a map into `(node, word)` pairs | no ² | [debauche2021comparison](@cite), Def. 10; [debauche2024thesis](@cite), Thm. 7.65 |
| [`BackwardCompositionLift`](@ref)`(T)` | templates closed under ``\circ A_i^{-1}``, invertible system | the forward one on the dual graphs | a map | no | [debauche2024thesis](@cite), Def. 7.61, Thm. 7.66 |

¹ The linear copositive norms are not closed under `min`, yet the min lift is
valid for them on positive systems ([debauche2024thesis](@cite), Thm. 7.43),
the one override of [`is_valid`](@ref).

² Sufficient only: [jongeneel2025ordering](@cite), Ex. IV.3, exhibits two
graphs ordered for every composition-closed template that no composition lift
simulates. The composition lift is also the one lift that can strictly improve
a graph (their Ex. IV.4), which is why [`Hierarchy`](@ref) accepts it as a
step of [`refine`](@ref).

Which lifts a template is entitled to is what it declares with
[`is_closed_under`](@ref), read by [`is_valid`](@ref); the table of
declarations is on the [Templates](@ref) page, and a closure declared on
either of a dual pair of templates serves both ([Duality](@ref)).

## `compare`

```julia
c = compare(G, H; templates = (QuadraticTemplate(),), system, optimizer)
lifts(c)        # the lifts tried, in order
simulations(c)    # lift => simulation, for each lift whose lifted G simulates H
templates(c)    # the templates given for which H is proved no worse than G
```

The lifts are tried cheapest and strongest first: the identity lift, whose
map settles the question for every template and stops the search; the min and
max lifts, by a relation; the sum lift, by the linear program, only when an
`optimizer` is given; the two composition lifts of length one. Pass your own
`lifts` to go further. A template is proved when some lift with a simulation is valid
for it on the `system`, which is required with `templates`.

Read without templates, a [`Comparison`](@ref) is the literature's statement:
``H`` is no worse than ``G`` for every template closed under the
[`requirements`](@ref) of each lift in [`simulations`](@ref).

## When a graph buys nothing

The one-node graph, [`common_graph`](@ref) of the system, simulates every graph, so
``G_0 \le_{\mathcal V} G`` always. The other direction is `compare(G, common_graph(system))`:
it holds for `min`-closed templates exactly when ``G`` has a nonempty complete
induced subgraph — every node of it has, for every mode, an edge reading that
mode into the subgraph — since the minimum of the node functions over that
subgraph is then a common function, and dually for `max` and a co-complete one
([debauche2021comparison](@cite), Prop. 3; [debauche2024thesis](@cite),
Cor. 7.53). The relation of the min lift finds that subgraph.

Measured: with the fixed-facet polyhedral template, which is `max`-closed, every
co-complete De Bruijn graph certifies exactly the one-node rate, at any order,
while the primal one improves; and on the positive system of
[debauche2023ordering](@cite) the copositive template gives the one-node rate
on the two graphs with a complete induced subgraph and strictly better rates on
the two without.

## Under duality

``G \le_{\mathcal V} H`` holds exactly when
``\mathrm{dual}(G) \le_{\mathcal V^*} \mathrm{dual}(H)``
([debauche2024thesis](@cite), Prop. 6.27). That is why every backward lift is
the dual of a forward one and decides its order on the dual graphs, and why a
question asked of the dual copositive template can be asked of the primal one
on the transposed system. See [Duality](@ref).
