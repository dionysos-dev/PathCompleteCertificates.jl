```@meta
CurrentModule = PathCompleteCertificates
```

# Templates

For stability, a template is a SetProg set family. Pass it directly to
[`certify`](@ref), [`jsr_bound`](@ref), [`compare`](@ref), or [`refine`](@ref).
[`functions`](@ref) returns fitted SetProg sets, each callable as `V(x)`.
The homogeneous sublevel function is the node's Lyapunov function.

```julia
using SetProg
family = Ellipsoid(symmetric = true)
certificate = PCC.jsr_bound(family, graph, problem; optimizer)
```

## Families

| SetProg family | Node function | Degree | Program |
| :-- | :-- | :-: | :-- |
| `Ellipsoid(symmetric = true)` | `x'Qx` | 2 | semidefinite |
| `Polytope(piecewise = :orthant)` | `c'x` on the nonnegative orthant | 1 | linear |
| `Polytope(piecewise = :orthant, polar = true)` | `maximum(x ./ v)` on the nonnegative orthant | 1 | linear |
| `Polytope(piecewise = :orthants, transform = G', polar = true)` | `maximum(abs.(G*x) ./ w)` | 1 | linear |
| `PolySet(symmetric = true, degree = 2d)` | sum-of-squares polynomial | 2d | semidefinite |
| `Ellipsoid(symmetric = true, piecewise = partition)` | quadratic on each partition cone | 2 | semidefinite |
| `Polytope(symmetric = true, piecewise = partition)` | linear on each partition cone | 1 | linear |

Load `SumOfSquares` before constructing a `PolySet`; otherwise SetProg gives
an error explaining the missing extension. Polynomial variables may be
supplied with `variables = x`, or inferred in a shared coordinate system.
SetProg is a direct dependency of PCC; its polynomial dependencies are optional.

The four polyhedral families use the same piecewise-linear representation.
The `:orthant` partition has one linear piece, restricted to the nonnegative
orthant; `:orthants` is a weighted absolute-value sum. Taking the polar gives
a box or parallelotope. Partition polytopes describe the linear pieces' regions
through the cones over their facets, allowing SetProg to use facet adjacency.
`polar` specifies the family;
SetProg chooses its modeling space from the constraints.

The existing `LinearCopositiveTemplate`, `DualCopositiveTemplate`,
`ParallelFacesPolyhedralTemplate`, and `ConicPolyhedralTemplate` constructors
also remain available. Positive-orthant families require nonnegative dynamics.
`PCC.planar_conic_partition(order; library)` supplies a partition polytope.
Pass one polytope per node to `ConicPolyhedralTemplate`; separate cone matrices
are no longer accepted. Its `min_scale` keyword scales the partition gauge
used for normalization.
The other polyhedral compatibility constructors retain their coefficient-floor
keyword arguments.

The degree `p`, returned by [`homogeneity_degree`](@ref), satisfies
`V(c*x) = c^p * V(x)`. Stability uses `rate^p` in each edge inequality,
so every family's rate bounds the joint spectral radius.
Ellipsoids and polynomial sets are normalized against the Euclidean unit gauge.
A finite `conditioning_bound` keyword in `certify` or `jsr_bound` also bounds
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
certificate = PCC.jsr_bound(families, graph, problem; optimizer)
```

[`reindex`](@ref) follows node origins through lifts. Copies retain their
origin's family, and merging nodes requires equal families.
All nodes must use gauges of the same degree.

## Deferred problems

Safety and optimal control still use [`QuadraticTemplate`](@ref) and their
existing fitted quadratic functions. Their migration to SetProg is deferred.
