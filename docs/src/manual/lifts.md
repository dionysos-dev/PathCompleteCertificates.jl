```@meta
CurrentModule = PathCompleteCertificates
```

# Lifts

A **lift** is an operation on a path-complete graph, and [`refine`](@ref) is an
algorithm that applies lifts. A lift `L` maps a graph ``G`` to a path-complete
graph ``L(G)`` that is no worse than ``G`` for every template closed under the
operations it requires: a certificate on ``G`` gives one on ``L(G)``. The
literature calls every operation below a lift.

Lifts serve two uses. [`refine`](@ref) applies them, one step at a time,
where a certificate is tight; see [Graph refinement](@ref). [`compare`](@ref)
asks whether ``L(G)`` simulates another graph ``H``, which proves
``G \le_{\mathcal V} H``; see [Graph comparison via lifts](@ref).

## Applying a lift

[`lift`](@ref)`(L, G)` applies `L` to the whole graph, `lift(L, G, edges)` at
each of the given edges, and `lift(L, G, node)` at a node; a lift has the forms
its definition gives it, and another form throws a `MethodError`. A lift
applied at edges is applied at every edge when none are given. The result is a
[`Lifted`](@ref): the graph and the [`origins`](@ref) of its nodes, what each
stands for in ``G``.

## The lifts

| Lift | Paper's name | Applied at | Requires | Used by |
| :-- | :-- | :-- | :-- | :-- |
| [`IdentityLift`](@ref) | | the whole graph | nothing | [`compare`](@ref) |
| [`ForwardSplitLift`](@ref) | forward lift at a node, [ninite2026lifting](@cite), Def. 3; partial P\*-lift at an edge, [athanasopoulos2019polyhedral](@cite), Def. 7 | a node, edges | nothing | [`TightNodeSplitting`](@ref), [`BestTightEdgeLifting`](@ref) |
| [`BackwardSplitLift`](@ref) | backward lift at a node, [ninite2026lifting](@cite); partial P-lift at an edge, [athanasopoulos2019polyhedral](@cite), Def. 6 | a node, edges | nothing | [`BestTightEdgeLifting`](@ref) |
| [`ForwardProductLift`](@ref) | partial T-lift, [athanasopoulos2019polyhedral](@cite), Def. 4 | edges | nothing | [`BestTightEdgeLifting`](@ref) |
| [`BackwardProductLift`](@ref) | partial T\*-lift, [athanasopoulos2019polyhedral](@cite), Def. 5 | edges | nothing | [`BestTightEdgeLifting`](@ref) |
| [`PathDependentLift`](@ref)`(M)` | ``M``-path-dependent lifting, [philippe2016stability](@cite), Def. 3 | the whole graph | nothing | [`Hierarchy`](@ref) |
| [`ProductLift`](@ref)`(T)` | ``T``-product lift, [philippe2016stability](@cite), Def. 2 | the whole graph | nothing | [`Hierarchy`](@ref) |
| [`MinLift`](@ref) | min lift, [debauche2021comparison](@cite) | the whole graph | `min` | [`compare`](@ref) |
| [`MaxLift`](@ref) | max lift, [debauche2021comparison](@cite) | the whole graph | `max` | [`compare`](@ref) |
| [`SumLift`](@ref)`(T)` | ``T``-sum lift, [debauche2021comparison](@cite), Def. 8 | the whole graph | `+` | [`compare`](@ref) |
| [`CompositionLift`](@ref)`(T)` | ``T``-forward composition lift, [debauche2024thesis](@cite), Def. 7.58 | the whole graph | composition with the dynamics | [`compare`](@ref), [`Hierarchy`](@ref) |
| [`BackwardCompositionLift`](@ref)`(T)` | ``T``-backward composition lift, [debauche2024thesis](@cite), Def. 7.61 | the whole graph | composition with the inverse dynamics | [`compare`](@ref) |

The last column gives the defaults; any lift can be passed to
[`Hierarchy`](@ref) or to the `lifts` of [`compare`](@ref) and
[`BestTightEdgeLifting`](@ref).

## Validity

A lift is **valid** for a template on a system when ``G \le_{\mathcal V} L(G)``
for every path-complete ``G`` ([debauche2021comparison](@cite), Defs. 6 and 7).
[`is_valid`](@ref) reads it from [`requirements`](@ref): the template, or its
dual on the dual system, must be closed under each operation listed, as
returned by [`is_closed_under`](@ref) and tabulated on the [Templates](@ref)
page. A lift that requires nothing is valid for every template: the splits give
each copy the function of the node it came from
([ninite2026lifting](@cite), Thm. 3), and the products chain two edge
inequalities ([athanasopoulos2019polyhedral](@cite), Thm. 1).

## Splits and products

The splits and products act at an edge ``(s, d, w)``, forward or backward.

Drawn at the edge `s ─w─▶ d` of a graph where `s` also reads `u` to `f` and
is entered by `a`, and `d` is also entered by `b` and leaves for `e`:

```
      before                      ForwardSplitLift               BackwardSplitLift

 a ──v──▶ s ──w──▶ d ──x──▶ e     a ──v──▶ s′ ──w──▶ d ──x──▶ e   a ──v──▶ s ──w──▶ d′ ──x──▶ e
          │        ▲              │                  ▲                     │
          u        t              v                  t                     u    b ──t──▶ d ──x──▶ e
          ▼        │              ▼                  │                     ▼
          f        b              s ──u──▶ f         b                     f

      ForwardProductLift                              BackwardProductLift

 a ──v──▶ s ──w·x──▶ e                                a ──v·w──▶ d ──x──▶ e
          │                                           │          ▲
          u          b ──t──▶ d ──x──▶ e              v          t
          ▼                                           ▼          │
          f                                           s ──u──▶ f b
```

A split adds a node and splits the inequalities that passed through it. A
product adds no node and writes a **word** on an edge: one inequality on
``A_x A_w`` with nothing imposed on the state in between, which is sound for
stability only. A [`WordGraph`](@ref) carries words, and its
[`expanded_form`](@ref) reads the same language with one mode per edge; for a
template closed under composition the two certify the same rate, the word
graph with fewer variables ([debauche2024thesis](@cite), Prop. 7.70).

At a node, [`ForwardSplitLift`](@ref) makes one copy per successor, owning
every edge to that successor, as in [ninite2026lifting](@cite), Def. 3; at an
edge it makes one copy owning that edge. The two agree unless two outgoing
edges of the node share a destination. On the one-node graph, whose only
successor is the node itself, the split at the node changes nothing.

Each backward lift is the [`dual`](@ref) of the forward one,
`dual(L)(G) = dual(L(dual(G)))`, and the classical hierarchies are lifts of the
whole graph:

- [`BackwardSplitLift`](@ref) at every edge is
  [`PathDependentLift`](@ref)`(1)`; iterated from the one-node graph it gives
  the [`de_bruijn`](@ref) graphs;
- either product at every edge is [`ProductLift`](@ref)`(2)`.

```@docs; canonical=false
lift
```
