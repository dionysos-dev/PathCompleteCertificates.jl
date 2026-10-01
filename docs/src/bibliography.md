```@meta
CurrentModule = PathCompleteCertificates
```

# Bibliography

Grouped by what each paper underwrites in the code, since that is usually how
you arrive: reading a predicate or a template, wanting its source.

## The framework

[ahmadi2014joint](@cite) introduced path-complete graph Lyapunov functions and
the joint-spectral-radius bound they give. The package is an implementation of
it.

[philippe2017path](@cite) is the authority for [Path-complete graphs](@ref):
Def. II.1 is [`is_path_complete`](@ref), Def. III.2 is [`is_complete`](@ref) and
[`is_co_complete`](@ref), and Cor. III.3 / Thm III.8 are what
[`common`](@ref) dispatches on.

## Template sources

[athanasopoulos2019polyhedral](@cite) is [`PolyhedralTemplate`](@ref) — the
symmetric ``2n``-face form, facets fixed, weights solved for.

[`ConicPolyhedralTemplate`](@ref), the free-facet form, is **not yet
published**; it is under submission. There is deliberately no entry for it,
rather than a citation to the nearest published neighbour that would credit the
wrong result.

[`QuadraticTemplate`](@ref) and [`LinearCopositiveTemplate`](@ref) are standard
and have no single source.

[parrilo2008approximation](@cite) is [`SumOfSquaresTemplate`](@ref): the
sum-of-squares relaxation of the joint spectral radius, whose bound tightens
monotonically with the degree.

## Problem sources

[anand2024barrier](@cite) is [`SafetyProblem`](@ref).
[anand2025completeness](@cite) is its follow-up on ordering barriers, not
implemented here.

[ninite2026path](@cite) is [`OptimalControlProblem`](@ref), including the
``S = P^{-1}``, ``Y = KS`` substitution.

[`StabilityProblem`](@ref) is [ahmadi2014joint](@cite) directly.

## Comparing, lifting and refining graphs

[debauche2021comparison](@cite) — a lift is any map on graphs preserving
path-completeness ([`AbstractLift`](@ref)), so it is sound whatever the
template. What the template's closure properties decide is *validity*
([`is_valid`](@ref)): whether the lifted graph is guaranteed no worse. Its sum,
min and max lifts are [`SumLift`](@ref), [`MinLift`](@ref) and
[`MaxLift`](@ref); the thesis behind it supplies the dual lift
([`DualLift`](@ref)) and the dual certificate.

[debauche2023ordering](@cite) — the linear program deciding the ordering for
templates closed under addition, [`conic_witness`](@ref). Its five graphs are
[Comparing graphs: which one is better?](@ref).

[philippe2017path](@cite) — the template-free ordering by simulation,
[`simulation`](@ref), and the ordering by relation that [`order_witness`](@ref)
runs for `min`- and `max`-closed templates.

[athanasopoulos2019polyhedral](@cite) — the four partial lifts,
[`ForwardEdgeSplit`](@ref), [`BackwardEdgeSplit`](@ref),
[`ForwardEdgeProduct`](@ref) and [`BackwardEdgeProduct`](@ref).

[jongeneel2025ordering](@cite) — [`CompositionLift`](@ref), and the reason it
needs invertible dynamics.

[ninite2026lifting](@cite) — [`refine`](@ref): split the node where the
certificate is tight, and stop when [`is_jsr_exact`](@ref) says the rate is the
joint spectral radius.

## All references

```@bibliography
```
