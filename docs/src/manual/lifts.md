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

The lifts of the literature, what each one is here, and what it asks of the
template. *Scope* is whether a lift rebuilds the whole graph or acts at a locus
of edges; *valid when* is the condition under which the lifted graph is
guaranteed no worse, which is what [`is_valid`](@ref) answers; *moves the
bound* is whether it can strictly improve a certificate at all.

| Lift | Here | Scope | Valid when | Moves the bound | Source |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Partial T-lift | [`ForwardEdgeProduct`](@ref) at an edge | local | always | yes | [athanasopoulos2019polyhedral](@cite), Def. 4 |
| Partial T\*-lift | [`BackwardEdgeProduct`](@ref) at an edge | local | always | yes | Def. 5 |
| Partial P-lift | [`BackwardEdgeSplit`](@ref) at an edge | local | always | yes | Def. 6 |
| Partial P\*-lift | [`ForwardEdgeSplit`](@ref) at an edge | local | always | yes | Def. 7 |
| Forward lift at a node | [`ForwardEdgeSplit`](@ref) on `outgoing_edges(graph, v)` | local | always | yes | [ninite2026lifting](@cite), Def. 3 |
| T-product lift | [`ProductLift`](@ref)`(T)`; either edge product on `edges(graph)` is `T = 2` | global | always | yes | [philippe2016stability](@cite), Def. 2 |
| M-path-dependent lift | [`PathDependentLift`](@ref)`(M)`; [`BackwardEdgeSplit`](@ref) on `edges(graph)` is `M = 1`; from the one-node graph it is [`de_bruijn`](@ref) | global | always | yes | [philippe2016stability](@cite), Def. 3 |
| Min lift | [`MinLift`](@ref) | global | closed under `min` ¹ | never | [debauche2021comparison](@cite), Def. 9 |
| Max lift | [`MaxLift`](@ref), which is `dual(MinLift())` | global | closed under `max` | never | Def. 9; [debauche2024thesis](@cite), Lemma 7.45 |
| T-sum lift | [`SumLift`](@ref)`(T)` | global | closed under `+` | never | Def. 8; [debauche2024thesis](@cite), Prop. 7.16 ² |
| T-forward composition lift | [`CompositionLift`](@ref)`(T)` | global | template and system closed under `∘ A` | yes | Def. 10; [debauche2024thesis](@cite), Def. 7.58; [jongeneel2025ordering](@cite), Def. III.1 ³ |
| T-backward composition lift | `dual(CompositionLift(T))` | global | closed under `∘ A⁻¹` | yes | [debauche2024thesis](@cite), Def. 7.61 ³ |
| Dual of a lift | [`dual`](@ref)`(lift)` | as the lift | the dual template | as the lift | [debauche2024thesis](@cite), Def. 7.4 and Prop. 7.5 |

"Always" is an argument rather than a theorem: a copy inherits its origin's
function and a product of two edges chains their two inequalities, so no new
function is formed and no closure is needed. "Never" is because the original
graph is a path-complete component of each subset lift: these three are
exhibits of an ordering question, decided without them in
[Comparing graphs](@ref).

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
  Philippe, Essick, Dullerud & Jungers, [`PathDependentLift`](@ref)`(1)`; iterated from
  the one-node graph it is [`de_bruijn`](@ref);
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

## Duality

`dual` is an involution on the whole problem: reverse the graph's edges and
words, transpose the system, take the dual template, and a certificate for one
is a certificate for the other — `dual(certificate)` builds it from the dual
norms of the node functions, at the same rate, without solving
([debauche2024thesis](@cite), Lemma 6.25). On a lift it is conjugation,
`dual(L)(G) = dual(L(dual(G)))`, which is how every backward lift and
[`MaxLift`](@ref) come from their forward counterparts with no code of their
own. Validity crosses over with it (Prop. 7.5), so [`is_valid`](@ref) also
accepts a lift whose dual is valid for the dual template: [`SumLift`](@ref) on
[`DualCopositiveTemplate`](@ref), whose primal norms add. A template with a
dual answers [`has_dual`](@ref).

## Three lifts that never move the bound

[`MinLift`](@ref), [`MaxLift`](@ref) and [`SumLift`](@ref) have nodes that are
subsets or multisets of the original nodes. The original graph is a
path-complete component of each, so for a template they are valid on the
lifted graph certifies exactly what the original did. They are not for
refining: they are the exhibits of the question *is this graph better than that
one for this template?*, which [Comparing graphs](@ref) answers without
building them.
