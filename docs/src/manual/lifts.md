```@meta
CurrentModule = PathCompleteCertificates
```

# Lifts

A **lift** turns a path-complete graph into another path-complete graph
([debauche2021comparison](@cite), Def. 5). That is its whole definition, and it
is why a lift is sound for free: path-completeness is the soundness condition,
so a certificate on the lifted graph certifies the system whatever the template.

What a lift *buys* is a different question, and it has two answers.

## Every lift, at a glance

The lifts of the literature, what each one is here, and what makes it valid.
*Scope* is whether a lift rebuilds the whole graph or acts at a locus of
edges. *Validity* is the condition under which the lifted graph is guaranteed
no worse, which [`is_valid`](@ref) answers; *depends on* says what that
condition reads — nothing, the template's closures, or the template's closures
on the system's dynamics.

| Lift | Here | Scope | Validity | Depends on | Source |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Partial T-lift | [`ForwardEdgeProduct`](@ref) at an edge | local | always | nothing | [athanasopoulos2019polyhedral](@cite), Def. 4 |
| Partial T\*-lift | [`BackwardEdgeProduct`](@ref) at an edge | local | always | nothing | [athanasopoulos2019polyhedral](@cite), Def. 5 |
| Partial P-lift | [`BackwardEdgeSplit`](@ref) at an edge | local | always | nothing | [athanasopoulos2019polyhedral](@cite), Def. 6 |
| Partial P\*-lift | [`ForwardEdgeSplit`](@ref) at an edge | local | always | nothing | [athanasopoulos2019polyhedral](@cite), Def. 7 |
| Forward lift at a node | [`ForwardEdgeSplit`](@ref) on `outgoing_edges(graph, v)` | local | always | nothing | [ninite2026lifting](@cite), Def. 3 |
| T-product lift | [`ProductLift`](@ref)`(T)` | global | always | nothing | [philippe2016stability](@cite), Def. 2 |
| M-path-dependent lift | [`PathDependentLift`](@ref)`(M)` | global | always | nothing | [philippe2016stability](@cite), Def. 3 |
| Min lift | [`MinLift`](@ref)`()` | global | closed under `min` ¹ | template | [debauche2021comparison](@cite), Def. 9 |
| Max lift | [`MaxLift`](@ref)`()` | global | closed under `max` | template | [debauche2021comparison](@cite), Def. 9; [debauche2024thesis](@cite), Lemma 7.45 |
| T-sum lift | [`SumLift`](@ref)`(T)` | global | closed under `+` | template | [debauche2021comparison](@cite), Def. 8; [debauche2024thesis](@cite), Prop. 7.16; [abate2026categorical](@cite), Ex. III.23 ² |
| T-forward composition lift | [`CompositionLift`](@ref)`(T)` | global | closed under `∘ A` | template and system | [debauche2021comparison](@cite), Def. 10; [debauche2024thesis](@cite), Def. 7.58; [jongeneel2025ordering](@cite), Def. III.1 ³ |
| T-backward composition lift | `dual(CompositionLift(T))` | global | closed under `∘ A⁻¹` | template and system | [debauche2024thesis](@cite), Def. 7.61 ³ |
| Dual of a lift | [`dual`](@ref)`(lift)` | as the lift | the dual template | as the lift | [debauche2024thesis](@cite), Def. 7.4 and Prop. 7.5 |

Three remarks the columns compress.

- **Where a lift comes from.** `ProductLift(2)` is either edge product on
  `edges(graph)`; `PathDependentLift(1)` is `BackwardEdgeSplit` on
  `edges(graph)`, and from the one-node graph the path-dependent lift is
  [`de_bruijn`](@ref); `MaxLift()` is `dual(MinLift())`, and the backward
  composition lift the dual of the forward one. The package builds each from
  the smaller piece rather than keeping two implementations.
- **"Always"** is an argument rather than a theorem: a copy inherits its
  origin's function and a product of two edges chains their two inequalities,
  so no new function is formed and no closure is needed.
- **Which lifts can move the bound.** All of them except the min, max and sum
  lifts, which never do: the original graph is a path-complete component of
  each, so they are exhibits of an ordering question, decided without building
  them in [Comparing graphs](@ref). The composition lifts are the one global
  family that can strictly improve a certificate.

¹ The copositive template is not closed under `min`, yet the min lift is valid
for it on positive systems ([debauche2024thesis](@cite), Thm. 7.43), the one
override of [`is_valid`](@ref).

² [abate2026categorical](@cite), Example III.23, extends the T-sum lift to
multisets of every size, with an edge wherever the `i`-edges inject the
destination multiset into the source one. At a fixed size that is the perfect
matching of Definition 8, so [`SumLift`](@ref)`(T)` is its restriction; the
edges between sizes serve to drop the path-completeness assumption from the
characterisation, which the package never needs since every graph it accepts is
path-complete.

³ Both composition lifts are corrected in [wintenberg2026complete](@cite), not
yet available. What is checked here is that they preserve path-completeness and
that the node functions they prescribe satisfy the lifted inequalities, which is
validity.

## Two atoms, and what they generate

Every refining construction in the literature is one of two local operations,
applied somewhere, or its dual.

| Operation | At one edge `(s, d, w)` | Source |
| :-- | :-- | :-- |
| [`ForwardEdgeSplit`](@ref) | a copy of `s` owning that outgoing edge and every incoming one | [athanasopoulos2019polyhedral](@cite), Def. 7 |
| [`BackwardEdgeSplit`](@ref) | a copy of `d` owning that incoming edge and every outgoing one | [athanasopoulos2019polyhedral](@cite), Def. 6 |
| [`ForwardEdgeProduct`](@ref) | replace it by `(s, d′, w·u)` for every `(d, d′, u)` | [athanasopoulos2019polyhedral](@cite), Def. 4 |
| [`BackwardEdgeProduct`](@ref) | replace it by `(s′, d, u·w)` for every `(s′, s, u)` | [athanasopoulos2019polyhedral](@cite), Def. 5 |

All four are valid for every template: a copy inherits its origin's function, a
product chains two edge inequalities.

Where they are applied is the **locus**, and the classical hierarchies are the
atoms at the full locus:

- `ForwardEdgeSplit` on `outgoing_edges(graph, s)` is the node split of
  [ninite2026lifting](@cite), which [`refine`](@ref) uses by default;
- `BackwardEdgeSplit` on `edges(graph)` is the path-dependent lift of
  [philippe2016stability](@cite), [`PathDependentLift`](@ref)`(1)`; iterated
  from the one-node graph it is [`de_bruijn`](@ref);
- either edge product on `edges(graph)` is [`ProductLift`](@ref)`(2)`, the
  product lift, which is self-dual.

A product writes **words** on the edges: an edge `(s, d, i₁…iₖ)` imposes one
inequality on ``A_{i_k} ⋯ A_{i_1}`` and costs no node. A [`WordGraph`](@ref)
carries them; every query accepts one; stability solves on one. Its
[`expanded_form`](@ref) reads the same language with one mode per edge, and for
a template closed under composition the two certify the same rate — the word
graph with fewer variables ([debauche2024thesis](@cite), Prop. 7.70). Words
never change what such a template can certify; they change what it costs.

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
linear systems ([debauche2024thesis](@cite), Thm. 7.43); one documented override
of `is_valid`.

## Every backward lift is a dual

Every backward lift here is the dual of a forward one, `dual(L)(G) =
dual(L(dual(G)))`, and a lift valid for a template has a dual valid for the
dual template. [Duality](@ref) is the account of that involution across
graphs, systems, templates, certificates and lifts; what it means for this
page is that [`BackwardEdgeSplit`](@ref), [`BackwardEdgeProduct`](@ref),
[`MaxLift`](@ref) and the backward composition lift have no code of their own,
and that [`is_valid`](@ref) reads the dual side when the primal one declares
nothing.

## Three lifts that never move the bound

[`MinLift`](@ref), [`MaxLift`](@ref) and [`SumLift`](@ref) have nodes that are
subsets or multisets of the original nodes. The original graph is a
path-complete component of each, so for a template they are valid on the
lifted graph certifies exactly what the original did. They are not for
refining: they are the exhibits of the question *is this graph better than that
one for this template?*, which [Comparing graphs](@ref) answers without
building them.
