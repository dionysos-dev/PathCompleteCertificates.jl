```@meta
CurrentModule = PathCompleteCertificates
```

# Lifts

A **lift** turns a path-complete graph into another path-complete graph
([debauche2021comparison](@cite), Def. 5). That is its whole definition, and it
is why a lift is sound for free: path-completeness is the soundness condition,
so a certificate on the lifted graph certifies the system whatever the template.

What a lift *buys* is a different question, and it has two answers.

## Two atoms, and what they generate

Every refining construction in the literature is one of two local operations,
applied somewhere, or its dual.

| Operation | At one edge `(s, d, w)` | Source |
| :-- | :-- | :-- |
| [`ForwardEdgeSplit`](@ref) | a copy of `s` owning that outgoing edge and every incoming one | [athanasopoulos2019polyhedral](@cite), Def. 7 |
| [`BackwardEdgeSplit`](@ref) | a copy of `d` owning that incoming edge and every outgoing one | Def. 6 |
| [`ForwardEdgeProduct`](@ref) | replace it by `(s, d′, w·u)` for every `(d, d′, u)` | Def. 4 |
| [`BackwardEdgeProduct`](@ref) | replace it by `(s′, d, u·w)` for every `(s′, s, u)` | Def. 5 |

All four are valid for every template: a copy inherits its origin's function, a
product chains two edge inequalities.

Where they are applied is the **locus**, and the classical hierarchies are the
atoms at the full locus:

- `ForwardEdgeSplit` on `outgoing_edges(graph, s)` is the node split of
  [ninite2026lifting](@cite), which [`refine`](@ref) uses by default;
- `BackwardEdgeSplit` on `edges(graph)` is the path-dependent lift of
  Philippe, Essick, Dullerud & Jungers, [`MemoryLift`](@ref)`(1)`; iterated from
  the one-node graph it is [`de_bruijn`](@ref);
- either edge product on `edges(graph)` is [`ProductLift`](@ref)`(2)`, the
  product lift, which is self-dual.

A product writes **words** on the edges: an edge `(s, d, i₁…iₖ)` imposes one
inequality on ``A_{i_k} ⋯ A_{i_1}`` and costs no node. A [`WordGraph`](@ref)
carries them; every query accepts one; stability solves on one. Its
[`expanded_form`](@ref) reads the same language with one mode per edge, and for
a template closed under composition the two certify the same rate — the word
graph with fewer variables ([debauche2021comparison](@cite), Prop. 7.70 of the
thesis). Words never change what such a template can certify; they change what
it costs.

The one refining lift that is not an atom at a locus is
[`CompositionLift`](@ref): a node commits to the next `T` modes and its function
is the original one composed with them. It needs a template closed under
[`Composition`](@ref) with invertible dynamics, and it can strictly improve a
bound the product lift cannot ([jongeneel2025ordering](@cite)).

## Validity: what the template declares

A template says which [`Operation`](@ref)s it is closed under with
[`is_closed_under`](@ref); a lift lists what it needs with
[`requirements`](@ref); [`is_valid`](@ref) is written once against the two. It
answers whether the lift is guaranteed not to make the bound **worse**
([debauche2021comparison](@cite), Def. 6). `false` never means unsound.

| Template | `+` | `max` | `min` | `∘ A` |
| :-- | :-: | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref) | ✓ | | | ✓ if invertible |
| [`SumOfSquaresTemplate`](@ref) | ✓ | | | ✓ if invertible |
| [`LinearCopositiveTemplate`](@ref) | ✓ | | valid on positive systems ¹ | ✓ if `A ≥ 0`, no zero column |
| [`DualCopositiveTemplate`](@ref) | | ✓ | | |
| [`PolyhedralTemplate`](@ref) | | ✓ if the node matrices coincide | | |

¹ Not closed as a set of functions, yet the min lift is valid for it on positive
linear systems (Debauche, Thm. 7.43); one documented override of `is_valid`.

## Duality

`dual` is an involution on the whole problem: reverse the graph's edges and
words, transpose the system, take the dual template, and a certificate for one
is a certificate for the other. On a lift it is conjugation,
`dual(L)(G) = dual(L(dual(G)))`, which is how every backward lift and
[`MaxLift`](@ref) come from their forward counterparts with no code of their
own.

## Three lifts that never move the bound

[`MinLift`](@ref), [`MaxLift`](@ref) and [`SumLift`](@ref) have nodes that are
subsets or multisets of the original nodes. The original graph is a
path-complete component of each, so for a template they are valid on the
lifted graph certifies exactly what the original did. They are not for
refining: they are the exhibits of the question *is this graph better than that
one for this template?*, which [Comparing graphs](@ref) answers without
building them.
