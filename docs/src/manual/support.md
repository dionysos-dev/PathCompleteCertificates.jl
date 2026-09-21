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
| [`PolyhedralTemplate`](@ref)        | ✓ | ✗ | ✗ |
| [`ConicPolyhedralTemplate`](@ref)   | ✓ | ✗ | ✗ |

¹ Entrywise nonnegative mode matrices only.

A ✗ throws an `ArgumentError` before any model is built. Optimal control
additionally requires a **complete** graph, not merely a path-complete one.

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
