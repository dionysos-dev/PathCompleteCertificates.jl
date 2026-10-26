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
Safety accepts quadratic and polynomial families; optimal control uses the
quadratic template.

|                                           | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :---------------------------------------- | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref)               | ✓ | ✓ | ✓ |
| [`SumOfSquaresTemplate`](@ref)            | ✓ | ✓ | |
| [`LinearCopositiveTemplate`](@ref)        | ✓ ¹ | | |
| [`DualCopositiveTemplate`](@ref)          | ✓ ¹ | | |
| [`ParallelFacesPolyhedralTemplate`](@ref) | ✓ | | |
| [`ConicPolyhedralTemplate`](@ref)         | ✓ | | |
| piecewise SetProg ellipsoid or polytope   | ✓ | | |

¹ Positive systems only: matrices with nonnegative entries.

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
| piecewise SetProg ellipsoid or polytope | sum if every node has the same partition |

The lifts used by refinement, the splits and the products, are valid for every
template. [`is_valid`](@ref) answers for a given template and system.

## Refinement and comparison

[`refine`](@ref) runs on [`StabilityProblem`](@ref) only, with a template that
measures its edge slacks: every template but [`SumOfSquaresTemplate`](@ref)
and the piecewise SetProg ellipsoids. [`compare`](@ref) reads graphs with one
mode per edge.

## The gaps

Each gap is either a method the package does not implement yet, or a question
the literature leaves open. [Extending the package](@ref) says where a new
template, problem, lift or refinement algorithm goes.

**Not implemented yet:**

- **safety with polyhedral or piecewise templates:** separation certificates
  currently support quadratic and polynomial functions;
- **optimal control on graphs that are not complete:** the convex program
  covers complete graphs only;
- **refinement with sums of squares and piecewise ellipsoids:** their edge
  slacks need an optimization of their own;
- **constrained switching**, for instance by an automaton: planned, see
  [issue #45](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues/45);
- **further problems** of the path-complete literature, such as stabilization.

**Open questions:**

- **optimal control with other templates:** the edge inequality is convex in
  the node function and the gain only after a change of variables, which the
  quadratic template admits;
- **refinement for safety and optimal control:** the results that guide
  refinement, where to lift and when to stop, are proved for stability.
