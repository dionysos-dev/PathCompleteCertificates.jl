```@meta
CurrentModule = PathCompleteCertificates
```

# Templates

For stability, use PCC's compatibility constructors or a SetProg set family.
Pass the template to [`certify`](@ref), [`compare`](@ref),
or [`refine`](@ref). For example:

```julia
family = PCC.QuadraticTemplate()
certificate = PCC.certify(family, graph, problem; optimizer)
```

`QuadraticTemplate()` returns `SetProg.Ellipsoid(symmetric = true)`. Stability
returns fitted SetProg sets, with ellipsoid matrices available as `V.Q`.
Evaluate a node with `node_value(problem, V, x)`, or the common Lyapunov
function with `certificate(x)`.

## Families

| Template or SetProg family | Node function | Degree | Program |
| :-- | :-- | :-: | :-- |
| `QuadraticTemplate()` | `x'Qx` | 2 | semidefinite |
| `Domain(Polytope(symmetric = true), MOI.Nonnegatives)` | `c'x` on the nonnegative orthant | 1 | linear |
| `DualCopositiveTemplate()` | `maximum(x ./ v)` on the nonnegative orthant | 1 | linear |
| `ParallelFacesPolyhedralTemplate([G])` | `maximum(abs.(G*x) ./ w)` | 1 | linear |
| `SumOfSquaresTemplate(d, x)` | sum-of-squares polynomial | 2d | semidefinite |
| `Ellipsoid(symmetric = true, piecewise = partition)` | quadratic on each partition cone | 2 | semidefinite |
| `Polytope(symmetric = true, piecewise = partition)` | linear on each partition cone | 1 | linear |

`SumOfSquaresTemplate(d, x; min_scale = 1)` returns a native
`PolySet(symmetric = true, degree = 2d, variables = x)` with its normalization
superset. `min_scale` preserves the lower bound on the Euclidean gauge.
Load `SumOfSquares` before constructing it or a `PolySet`; otherwise SetProg gives
an error explaining the missing extension. Polynomial variables may be
supplied with `variables = x`, or inferred in a shared coordinate system.
SetProg is a direct dependency of PCC; its polynomial dependencies are optional.

`Domain(Polytope(symmetric = true), MOI.Nonnegatives)` has one linear piece
restricted to the nonnegative orthant, with its dimension inferred from the
model. PCC normalizes its coefficients to be at least one using a fixed
unit-simplex inclusion. Partition polytopes describe the linear pieces'
regions through the cones over their facets, retaining facet adjacency.
A cross-polytope supplies the orthant partition for parallel-face families.
SetProg chooses the modeling space from the normalization constraints.

The existing `LinearCopositiveTemplate`, `DualCopositiveTemplate`,
`ParallelFacesPolyhedralTemplate`, and `ConicPolyhedralTemplate` constructors
also remain available. Positive-orthant families require nonnegative dynamics.
`PCC.planar_conic_partition(order; library)` supplies a partition polytope.
Pass one polytope per node to `ConicPolyhedralTemplate`; separate cone matrices
are no longer accepted. Its `min_scale` keyword scales the partition gauge
used for normalization.
The other polyhedral compatibility constructors retain their coefficient-floor
keyword arguments.

`DualCopositiveTemplate` and `ParallelFacesPolyhedralTemplate` retain their
compatibility constructors. A PCC normalization adapter stores the native
SetProg family and a fixed reference set. Requiring that reference to lie in
the variable selects dual modeling through SetProg's inclusion rules;
`min_weight` remains a lower bound on the box widths. Parallel-face families
also impose central symmetry using `-S ⊆ S`. No variable polarity option is
used, and normalization and gauge evaluation stay in PCC.

The degree `p`, returned by [`homogeneity_degree`](@ref), satisfies
`V(c*x) = c^p * V(x)`. Stability uses `rate^p` in each edge inequality,
so every family's rate bounds the joint spectral radius.
Ellipsoids and polynomial sets are normalized against the Euclidean unit gauge.
A finite `conditioning_bound` keyword in `certify` also bounds
an ellipsoid's matrix by `conditioning_bound * I`; the default is `Inf`.

Clarabel solves semidefinite and linear models; HiGHS solves linear models.

## Closure and duality

Graph operations remain in PCC. [`is_closed_under`](@ref) declares a family's
closures; [`is_valid`](@ref) checks a lift, also using the dual family when available.

| Family | Addition | Maximum | Composition with invertible dynamics |
| :-- | :-: | :-: | :-- |
| symmetric ellipsoid | ✓ | | ✓ |
| polynomial set | ✓ | | ✓ |
| positive simplex | ✓ | | if nonnegative with no zero column |
| positive box | | ✓ | |
| parallelotope | | ✓ when all node matrices coincide | |
| conic polytope | | | |
| piecewise ellipsoid or polytope | ✓ when the nodes share a partition | | |

Symmetric nonpiecewise ellipsoids are self-dual. Positive simplices and boxes
are each other's blocking duals on the nonnegative orthant. Other families
have no fitted dual implementation here. See [Duality](@ref).

## Per-node data

A single family is shared by all nodes. A vector supplies one family per node:

```julia
families = PCC.ParallelFacesPolyhedralTemplate([G1, G2])
certificate = PCC.certify(families, graph, problem; optimizer)
```

[`reindex`](@ref) follows node origins through lifts. Copies retain their
origin's family, and merging nodes requires equal families.
All nodes must use gauges of the same degree.

## Deferred problems

Safety and optimal control still use [`QuadraticTemplate`](@ref) and their
existing fitted quadratic functions. Their migration to SetProg is deferred.
