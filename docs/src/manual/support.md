```@meta
CurrentModule = PathCompleteCertificates
```

# What works with what

In principle every template composes with every problem. In practice two of the
three problems are still quadratic-only.

|                                | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :----------------------------- | :------------------------: | :---------------------: | :-----------------------------: |
| [`QuadraticTemplate`](@ref)         | ✓ | ✓ | ✓ |
| [`LinearCopositiveTemplate`](@ref)  | ✓ ¹ | ✗ | ✗ |
| [`DualCopositiveTemplate`](@ref)    | ✓ ¹ | ✗ | ✗ |
| [`PolyhedralTemplate`](@ref)        | ✓ | ✗ | ✗ |
| [`ConicPolyhedralTemplate`](@ref)   | ✓ | ✗ | ✗ |
| [`SumOfSquaresTemplate`](@ref)      | ✓ ² | ✗ | ✗ |

¹ Entrywise nonnegative mode matrices only.

² Behind a package extension: `using SumOfSquares` first, or its primitives are
not defined.

A ✗ throws an `ArgumentError` before any model is built. Optimal control
additionally requires a **complete** graph, not merely a path-complete one.
Stability accepts a [`WordGraph`](@ref); safety and optimal control need one
mode per edge and say so.

## And the stability column for refinement

[`refine`](@ref) designs the graph rather than taking one, so it is not a column
of the table above — it sits on top of the stability column, for every template
that answers [`domination_slack`](@ref):

| | [`StabilityProblem`](@ref) |
| :-- | :-: |
| [`QuadraticTemplate`](@ref) | ✓ |
| [`LinearCopositiveTemplate`](@ref) | ✓ ¹ |
| [`DualCopositiveTemplate`](@ref) | ✓ ¹ |
| [`PolyhedralTemplate`](@ref) | ✓ |
| [`ConicPolyhedralTemplate`](@ref) | ✓ |
| [`SumOfSquaresTemplate`](@ref) | ✗ ³ |

³ No `domination_slack` yet, so the loop cannot read where that template is
tight.

The lifts it applies preserve path-completeness, which is the soundness
condition, and need nothing from the template besides; a template with per-node
data follows the graph through [`reindex`](@ref). Safety refines on its margin
with no optimality gap. Optimal control does not refine: its edge inequality
does not factor through [`add_domination!`](@ref), so it has no slacks to read.

## The two gaps are different

**Safety** imposes its inequality on the homogeneous lift, which the polyhedral
templates could support — the construction is sound, the plumbing is not
written. Expect this gap to close.

**Optimal control** is convex only after the substitution ``S = P^{-1}``,
``Y = KS``, which is specific to the quadratic case. This one is a property of
the mathematics, not of missing work ([ninite2026path](@cite)).

## Filling a cell

A new template gives you the whole stability column; a new problem gives you
every template it accepts. Neither touches the other axis. See the
[developer conventions](@ref "Coding conventions").

!!! warning "A template is an instance, never a type"
    Pass `QuadraticTemplate()`, not `QuadraticTemplate`.
