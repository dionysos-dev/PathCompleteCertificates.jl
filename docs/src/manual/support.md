```@meta
CurrentModule = PathCompleteCertificates
```

# What works with what

This page says which combinations the package supports: the templates each
problem accepts, the lifts valid for each template, and where refinement and
comparison apply. It is also a map of what is missing. The package aims to
implement the state of the art on path-complete certificates, and each gap
below is a place where research or a contribution can close it.

## Templates and problems

Stability accepts every template, including SetProg families passed directly.
Safety accepts quadratic, polynomial, and polyhedral families. Optimal control
jointly synthesizes quadratic values and gains. Convex polynomial values, from
`SumOfSquaresTemplate(r; convex = true)` or a convex homogeneous PolySet, are
optimized for fixed or initialized gains.

|                                           | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :---------------------------------------- | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref)               | ✓ | ✓ | ✓ |
| [`SumOfSquaresTemplate`](@ref)            | ✓ | ✓ | ✓ ³ |
| [`LinearCopositiveTemplate`](@ref)        | ✓ ¹ | | |
| [`DualCopositiveTemplate`](@ref)          | ✓ ¹ | | |
| [`ParallelFacesPolyhedralTemplate`](@ref) | ✓ | ✓ ² | |
| [`ConicPolyhedralTemplate`](@ref)         | ✓ | ✓ ² | |
| [`PiecewiseQuadraticTemplate`](@ref)      | ✓ | | |
| convex homogeneous SetProg PolySet       | ✓ | ✓ | ✓ ³ |

¹ Positive systems only: matrices with nonnegative entries.

² Polyhedral safety currently supports a bounded ellipsoidal initial region
and an unsafe region equal to the exterior of a bounded ellipsoid. It uses
linear and second-order cone constraints.

³ Set `OptimalControlProblem(...; p = degree)` with a matching homogeneous
degree and convex node functions: `SumOfSquaresTemplate(r; convex = true)` with
`p = 2r`, or a PolySet with `convex = true`. Supply node gains with `gains = ...`, or
omit them to initialize with the quadratic solver. The polynomial SDP minimizes
the integral of the value bounds and keeps the gain matrices fixed.

Unsupported combinations report an error before anything is solved. Two more conditions on the graph:

- optimal control needs a **complete** graph, not only a path-complete one;
- a [`WordGraph`](@ref), with sequences of modes on its edges, is accepted by
  stability only: for safety and optimal control, the states inside a word
  would go unchecked.

## Lifts and templates

| Template | Lifts valid for it, beyond the identity |
| :-- | :-- |
| [`QuadraticTemplate`](@ref) | sum; composition and backward composition if the matrices are invertible |
| [`SumOfSquaresTemplate`](@ref) | sum; composition and backward composition if the matrices are invertible |
| [`LinearCopositiveTemplate`](@ref) | sum; composition if the matrices are nonnegative with no zero column; backward composition if they are invertible with nonnegative inverses; through its dual: min |
| [`DualCopositiveTemplate`](@ref) | max; through its dual: sum, composition if the matrices are invertible with nonnegative inverses, backward composition if they are nonnegative with no zero row |
| [`ParallelFacesPolyhedralTemplate`](@ref) | max if every node has the same faces |
| [`ConicPolyhedralTemplate`](@ref) | sum if every node has the same partition |
| [`PiecewiseQuadraticTemplate`](@ref) | sum if every node has the same partition |

The lifts used by refinement, the splits and the products, are valid for every
template. [`is_valid`](@ref) answers for a given template and system.

## Refinement and comparison

[`refine`](@ref) runs on [`StabilityProblem`](@ref) only, with a template that
measures its edge slacks: every template but [`SumOfSquaresTemplate`](@ref)
and [`PiecewiseQuadraticTemplate`](@ref). [`compare`](@ref) reads graphs with one
mode per edge.

## The gaps

Each gap is either a method the package does not implement yet, or a question
the literature leaves open. [Extending the package](@ref) says where a new
template, problem, lift or refinement algorithm goes.

**Not implemented yet:**

- **safety with copositive or piecewise-quadratic templates**, and polyhedral
  separation from a bounded unsafe obstacle;
- **optimal control on graphs that are not complete:** the convex program
  covers complete graphs only;
- **refinement with sums of squares and piecewise quadratic functions:** their edge
  slacks need an optimization of their own;
- **constrained switching**, for instance by an automaton: planned, see
  [issue #45](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues/45);
- **further problems** of the path-complete literature, such as stabilization.

**Open questions:**

- **joint optimal-control synthesis beyond quadratic templates:** polynomial
  value optimization currently uses fixed gains. Joint gain/value search
  requires a suitable convexification or a nonconvex algorithm;
- **refinement for safety and optimal control:** the results that guide
  refinement, where to lift and when to stop, are proved for stability.
