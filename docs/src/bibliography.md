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

## Problem sources

[anand2024barrier](@cite) is [`SafetyProblem`](@ref).
[anand2025completeness](@cite) is its follow-up on ordering barriers, not
implemented here.

[ninite2026path](@cite) is [`OptimalControlProblem`](@ref), including the
``S = P^{-1}``, ``Y = KS`` substitution.

[`StabilityProblem`](@ref) is [ahmadi2014joint](@cite) directly.

## Designed, not implemented

Both describe traps that fail *silently*.

[debauche2021comparison](@cite) — whether a lift may be applied depends on the
template's analytical properties, not on the graph alone. Skip that check and
you get a certificate that certifies nothing.

[jongeneel2025ordering](@cite) — ordering and refining path-complete Lyapunov
functions through composition lifts. The work named in [Status](@ref).

## All references

```@bibliography
```
