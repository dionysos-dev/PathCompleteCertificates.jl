```@meta
CurrentModule = PathCompleteCertificates
```

# What works with what

## Templates and problems

Stability accepts every template, and SetProg families directly. Safety and
optimal control use the quadratic template.

|                                           | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :---------------------------------------- | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref)               | ✓ | ✓ | ✓ |
| [`SumOfSquaresTemplate`](@ref)            | ✓ | | |
| [`LinearCopositiveTemplate`](@ref)        | ✓ ¹ | | |
| [`DualCopositiveTemplate`](@ref)          | ✓ ¹ | | |
| [`ParallelFacesPolyhedralTemplate`](@ref) | ✓ | | |
| [`ConicPolyhedralTemplate`](@ref)         | ✓ | | |
| piecewise SetProg ellipsoid or polytope   | ✓ | | |

¹ Positive systems only: matrices with nonnegative entries.

An unsupported combination throws an `ArgumentError` before anything is
solved. Two more conditions on the graph:

- optimal control needs a **complete** graph, not only a path-complete one;
- a [`WordGraph`](@ref), with sequences of modes on its edges, is accepted by
  stability only.

## Lifts and templates

| Template | Lifts valid for it, beyond the identity |
| :-- | :-- |
| [`QuadraticTemplate`](@ref) | sum; composition if the matrices are invertible |
| [`SumOfSquaresTemplate`](@ref) | sum; composition if the matrices are invertible |
| [`LinearCopositiveTemplate`](@ref) | sum, and min through its dual; composition if the matrices are nonnegative with no zero column |
| [`DualCopositiveTemplate`](@ref) | max, and sum through its dual |
| [`ParallelFacesPolyhedralTemplate`](@ref) | max if every node has the same faces |
| [`ConicPolyhedralTemplate`](@ref) | none |
| piecewise SetProg ellipsoid or polytope | sum if every node has the same partition |

The lifts used by refinement, the splits and the products, are valid for every
template. [`is_valid`](@ref) answers for a given template and system.

## Refinement and comparison

[`refine`](@ref) runs on [`StabilityProblem`](@ref) only, with a template that
measures its edge slacks: every template but [`SumOfSquaresTemplate`](@ref)
and the piecewise SetProg ellipsoids. [`compare`](@ref) reads graphs with one
mode per edge.
