```@meta
CurrentModule = PathCompleteCertificates
```

# What works with what

Every template composes with every problem in principle. In practice,
stability runs on all six templates, and the two other problems on the
quadratic one.

|                                | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :----------------------------- | :------------------------: | :---------------------: | :-----------------------------: |
| [`QuadraticTemplate`](@ref)         | ✓ | ✓ | ✓ |
| [`LinearCopositiveTemplate`](@ref)  | ✓ ¹ | ✗ | ✗ |
| [`DualCopositiveTemplate`](@ref)    | ✓ ¹ | ✗ | ✗ |
| [`PolyhedralTemplate`](@ref)        | ✓ | ✗ | ✗ |
| [`ConicPolyhedralTemplate`](@ref)   | ✓ | ✗ | ✗ |
| [`SumOfSquaresTemplate`](@ref)      | ✓ ² | ✗ | ✗ |

¹ Positive systems only: entrywise nonnegative mode matrices.

² Behind a package extension: `using SumOfSquares` first, or its primitives are
not defined.

A ✗ throws an `ArgumentError` before any model is built. Optimal control needs
a **complete** graph, not merely a path-complete one. Stability accepts a
[`WordGraph`](@ref); safety and optimal control need one mode per edge.

## Comparing and refining

[`compare`](@ref) is written for stability, where the theory is; it asks a
question about graphs, and which of its verdicts hold for a template is read
from the template's closure properties. [`refine`](@ref) runs on stability and
safety, for every template that answers [`domination_slack`](@ref), which is
how the loop reads where a certificate is tight:

| | [`refine`](@ref) | lifts valid for [`compare`](@ref) |
| :-- | :-: | :-- |
| [`QuadraticTemplate`](@ref) | ✓ | identity, sum; composition if invertible |
| [`LinearCopositiveTemplate`](@ref) | ✓ ¹ | identity, sum, min without closure; composition if nonnegative with no zero column |
| [`DualCopositiveTemplate`](@ref) | ✓ ¹ | identity, max; sum through its dual |
| [`PolyhedralTemplate`](@ref) | ✓ | identity; max when the node matrices coincide |
| [`ConicPolyhedralTemplate`](@ref) | ✓ | identity |
| [`SumOfSquaresTemplate`](@ref) | ✗ ³ | identity, sum; composition if invertible |

³ No `domination_slack` yet, so the loop cannot read where that template is
tight.

## The gaps

Safety with the polyhedral templates is possible in principle, by the same
construction in homogeneous coordinates; it is not implemented. Optimal
control is tied to the quadratic template by the mathematics, the substitution
``S = P^{-1}``, ``Y = KS`` that makes it convex ([ninite2026path](@cite)). A
new template gives the whole stability column at once, and the two other
problems once it answers their primitives; see the
[developer conventions](@ref "Conventions").
