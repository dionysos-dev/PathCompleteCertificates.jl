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

## The graph layer

Lifting, comparing, refining and words on edges are written for stability,
where the theory is. [`refine`](@ref) is generic in the problem, reading only
[`best_certificate`](@ref), [`objective`](@ref) and
[`optimality_gap`](@ref), but today only [`StabilityProblem`](@ref) answers
them. Within stability it runs for every template that answers
[`domination_slack`](@ref), which is how the loop reads where a certificate is
tight:

| | [`refine`](@ref) | [`order_witness`](@ref) |
| :-- | :-: | :-: |
| [`QuadraticTemplate`](@ref) | ✓ | map, linear program |
| [`LinearCopositiveTemplate`](@ref) | ✓ ¹ | map, linear program; min lift valid without closure |
| [`DualCopositiveTemplate`](@ref) | ✓ ¹ | map, relation on the duals |
| [`PolyhedralTemplate`](@ref) | ✓ | map; relation on the duals when the node matrices coincide |
| [`ConicPolyhedralTemplate`](@ref) | ✓ | map |
| [`SumOfSquaresTemplate`](@ref) | ✗ ³ | map, linear program |

³ No `domination_slack` yet, so the loop cannot read where that template is
tight.

The second column is what the template's closures entitle
[`order_witness`](@ref) to run; see [Comparing graphs](@ref). A template with
per-node data follows a lifted graph through [`reindex`](@ref).

## The two gaps are different

**Safety** imposes its inequality on the homogeneous lift, which the polyhedral
templates could support: the construction is sound, the plumbing is not
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
