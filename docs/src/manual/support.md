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

For each template, the program that each problem solves with it, linear (LP),
second-order cone (SOCP) or semidefinite (SDP):

| Template | [`StabilityProblem`](@ref) | [`SafetyProblem`](@ref) | [`OptimalControlProblem`](@ref) |
| :-- | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref)`()` | SDP | SDP | SDP |
| [`PiecewiseQuadraticTemplate`](@ref)`(P)` † | SDP | SDP | SDP § |
| [`SumOfSquaresTemplate`](@ref)`(r)` † | SDP | SDP | SDP § |
| [`PiecewiseLinearTemplate`](@ref)`(P)` | LP | SOCP ‡ | LP or SOCP § |
| [`DualPiecewiseLinearTemplate`](@ref)`(P)` | LP | SOCP ‡ | × |
| [`LinearCopositiveTemplate`](@ref)`()` * | LP | × | × |
| [`DualCopositiveTemplate`](@ref)`()` * | LP | × | × |

\* For positive systems, whose matrices have nonnegative entries.

† Not available to [`refine`](@ref): its edge slacks are not implemented.

‡ For an ellipsoidal initial set ``X_0`` and an unsafe set ``X_u`` outside an
ellipsoid.

§ With fixed gains, by default those of the quadratic certificate. Polynomial
node functions must be convex, with `SumOfSquaresTemplate(r; convex = true)`.
The piecewise linear template solves a linear program for `p = 1` and a
second-order cone program for `p = 2`, whether `Q` and `R` are matrices or
polytopes.

× Not supported: see [The gaps](@ref).

For optimal control, the exponent `p` of the cost (see
[Systems and problems](@ref)) must match the template: 2 for the quadratic and
piecewise quadratic templates, ``2r`` for
`SumOfSquaresTemplate(r; convex = true)`, and 1 or 2 for the piecewise linear
template, whose node functions are then the gauges ``g_{\Omega_s}^p``. A cost
given by polytopes ``\mathcal Q`` and ``\mathcal R`` works with the piecewise
linear template only. The other templates need the matrices ``Q`` and ``R``.

Unsupported combinations report an error before anything is solved. Two more
conditions are on the graph:

- **Optimal control** needs a **complete** graph, not only a path-complete
  one.
- **A [`WordGraph`](@ref)**, with sequences of modes on its edges, is
  accepted by stability only. For safety and optimal control, the states
  inside a word would go unchecked.

## Lifts and templates

| Template | Lifts valid for it, beyond the identity |
| :-- | :-- |
| [`QuadraticTemplate`](@ref) | sum. Composition and backward composition if the matrices are invertible. |
| [`PiecewiseQuadraticTemplate`](@ref) | sum if every node has the same partition. |
| [`SumOfSquaresTemplate`](@ref) | sum. Composition and backward composition if the matrices are invertible. |
| [`PiecewiseLinearTemplate`](@ref) | sum if every node has the same partition. Through its dual: min, if that partition is a cross-polytope. |
| [`DualPiecewiseLinearTemplate`](@ref) | max if every node has the same partition, a cross-polytope. Through its dual: sum if every node has the same partition. |
| [`LinearCopositiveTemplate`](@ref) | sum. Composition if the matrices are nonnegative with no zero column. Backward composition if they are invertible with nonnegative inverses. Through its dual: min. |
| [`DualCopositiveTemplate`](@ref) | max. Through its dual: sum, composition if the matrices are invertible with nonnegative inverses, and backward composition if they are nonnegative with no zero row. |

The lifts used by refinement, the splits and the products, are valid for every
template. [`is_valid`](@ref) answers for a given template and system.

## Refinement and comparison

[`refine`](@ref) runs on [`StabilityProblem`](@ref) only, with the templates
without † in the table above. [`compare`](@ref) reads graphs with one mode per
edge.

## Duals

[`dual`](@ref) applies to graphs, lifts, systems without input, stability
problems and stability certificates. Among the templates, the quadratic one is
its own dual, and the piecewise linear and copositive pairs are each other's.
The sum-of-squares and piecewise quadratic templates have no dual, and
neither do safety and optimal control.

## The gaps

Each gap is either a method the package does not implement yet, or a question
the literature leaves open. [Extending the package](@ref) says where a new
template, problem, lift or refinement strategy goes.

**Not implemented yet:**

- **The × cells of the table:** safety and optimal control with the
  copositive templates, and optimal control with the dual piecewise linear
  template.
- **Polyhedral safety with other sets,** such as a bounded unsafe obstacle.
- **Optimal control on graphs that are not complete:** the convex program
  covers complete graphs only.
- **Refinement with sums of squares and piecewise quadratic functions:**
  their edge slacks need an optimization of their own.
- **Constrained switching**, for instance by an automaton: planned, see
  [issue #45](https://github.com/dionysos-dev/PathCompleteCertificates.jl/issues/45).
- **Further problems** of the path-complete literature, such as
  stabilization.

**Open questions:**

- **Joint optimal-control synthesis beyond the quadratic template:** the
  other templates use fixed gains. Computing the gains and the node functions
  together needs a convex reformulation or a nonconvex algorithm.
- **Refinement for safety and optimal control:** the results that guide
  refinement, where to lift and when to stop, are proved for stability.
