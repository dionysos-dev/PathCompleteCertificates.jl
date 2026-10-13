```@meta
CurrentModule = PathCompleteCertificates
```

# What works with what

Stability is implemented for all seven templates, safety and optimal control
for the quadratic one.

|                                | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :----------------------------- | :------------------------: | :---------------------: | :-----------------------------: |
| [`QuadraticTemplate`](@ref)         | ✓ | ✓ | ✓ |
| [`LinearCopositiveTemplate`](@ref)  | ✓ ¹ | ✗ | ✗ |
| [`DualCopositiveTemplate`](@ref)    | ✓ ¹ | ✗ | ✗ |
| [`PolyhedralTemplate`](@ref)        | ✓ | ✗ | ✗ |
| [`ConicPolyhedralTemplate`](@ref)   | ✓ | ✗ | ✗ |
| [`SumOfSquaresTemplate`](@ref)      | ✓ ² | ✗ | ✗ |
| [`SetProgTemplate`](@ref)           | ✓ ² | ✗ | ✗ |

¹ Positive systems only: entrywise nonnegative mode matrices.

² Behind a package extension: `using SumOfSquares` first, or `using SetProg`
for [`SetProgTemplate`](@ref).

A ✗ throws an `ArgumentError` before any model is built. Optimal control needs
a **complete** graph, not merely a path-complete one. Stability accepts a
[`WordGraph`](@ref); safety and optimal control need one mode per edge.

## Comparing and refining

[`compare`](@ref) is stated for stability, as in the literature; which of its
results hold for a template depends on the template's closure properties.
[`refine`](@ref) runs on stability and safety, for every template that
implements [`domination_slack`](@ref), from which the edge slacks are computed:

| | [`refine`](@ref) | lifts valid for [`compare`](@ref) |
| :-- | :-: | :-- |
| [`QuadraticTemplate`](@ref) | ✓ | identity, sum; composition if invertible |
| [`LinearCopositiveTemplate`](@ref) | ✓ ¹ | identity, sum, min without closure; composition if nonnegative with no zero column |
| [`DualCopositiveTemplate`](@ref) | ✓ ¹ | identity, max; sum through its dual |
| [`PolyhedralTemplate`](@ref) | ✓ | identity; max when the node matrices coincide |
| [`ConicPolyhedralTemplate`](@ref) | ✓ | identity |
| [`SumOfSquaresTemplate`](@ref) | ✗ ³ | identity, sum; composition if invertible |
| [`SetProgTemplate`](@ref) | ✗ ³ | identity; sum when the nodes share the set variable |

³ No `domination_slack` yet, so the loop cannot read where these templates are
tight.

## The gaps

Safety with the polyhedral templates is possible by the same construction in
homogeneous coordinates; it is not implemented. Optimal
control is tied to the quadratic template by the mathematics, the substitution
``S = P^{-1}``, ``Y = KS`` that makes it convex ([ninite2026path](@cite)). A
new template that implements the template primitives works with stability;
safety and optimal control need further primitives; see the
[developer conventions](@ref "Conventions").
