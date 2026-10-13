```@meta
CurrentModule = PathCompleteCertificates
```

# Templates

A template defines the search space from which the node functions of a
certificate are chosen. Its properties depend on the problem: for stability,
the template consists of candidate Lyapunov functions, continuous, positive
definite and homogeneous; for safety, of candidate barrier functions, which
need not be positive. Once a certificate has been computed,
[`functions`](@ref) returns the fitted node functions, one per node, each
callable.

## The seven templates

| Template | ``V_s(x)`` | Homogeneity degree | Solved for | Source |
| :-- | :-- | :-: | :-- | :-- |
| [`QuadraticTemplate`](@ref) | ``x^\top P_s x`` | 2 | ``P_s \succ 0`` | standard |
| [`LinearCopositiveTemplate`](@ref) | ``c_s^\top x`` on the nonnegative orthant | 1 | ``c_s > 0`` | standard |
| [`DualCopositiveTemplate`](@ref) | ``\max_i x_i / v_{s,i}`` on the nonnegative orthant | 1 | ``v_s > 0`` | [debauche2024thesis](@cite), Def. 2.30 |
| [`ParallelFacesPolyhedralTemplate`](@ref) | ``\max_k \lvert (G_s x)_k \rvert / w_{s,k}`` | 1 | weights ``w_s``, facets ``G_s`` fixed | [athanasopoulos2019polyhedral](@cite) |
| [`ConicPolyhedralTemplate`](@ref) | ``\max_i \lvert p_{s,i}^\top x \rvert`` | 1 | facets ``p_{s,i}`` | unpublished ¹ |
| [`SumOfSquaresTemplate`](@ref) | ``z(x)^\top Q_s z(x)``, ``z`` the monomials of degree ``d`` | ``2d`` | ``Q_s \succeq 0`` | [parrilo2008approximation](@cite) ² |
| [`SetProgTemplate`](@ref) | the gauge of a [SetProg](https://github.com/blegat/SetProg.jl) set | the set's | the set | ³ |

¹ The free-facet construction is under submission.

² Behind a package extension: load SumOfSquares first. Raising ``d`` tightens
the bound monotonically, and ``d = 1`` is exactly [`QuadraticTemplate`](@ref).

³ Behind a package extension: load SetProg first. Its ellipsoids, polynomial
sets and piecewise polytopes give the quadratic, sum-of-squares and free-facet
templates. Its piecewise semi-ellipsoids, quadratic on each cone of a
partition, improve on the quadratic template as the partition is refined;
[Piecewise semi-ellipsoids: a template from SetProg](@ref) shows all four.

The **homogeneity degree**, [`homogeneity_degree`](@ref), is the ``p`` in
``V(cx) = c^p V(x)``. Stability scales its edge inequality by ``\gamma^p``, so
the rate bounds the joint spectral radius in every template, and rates from
different templates can be compared. For safety the quadratic template is used in homogeneous
coordinates, ``[x; 1]^\top P_s [x; 1]``, without positive definiteness.

**The two polyhedral templates.** Both search symmetric polytopes with a
linear program. [`ParallelFacesPolyhedralTemplate`](@ref) fixes the face
normals, the rows of ``G_s``, and solves for the distances ``w_s`` of the
faces, ``n`` variables per node. [`ConicPolyhedralTemplate`](@ref) fixes the
vertex directions, the rays of a conic partition, and solves for the faces,
one row of ``n`` variables per cone.

**The two copositive templates** are each other's duals, the dual norm of
``c^\top x`` on the orthant being ``\max_i x_i / c_i``. Both are defined on
the nonnegative orthant, so they apply to positive systems only: on any other,
[`is_applicable`](@ref) is `false` and stability throws.

## Classes and solvers

Several templates search subsets of one class of functions. The class sets the
kind of program, and so the solver to pass as `optimizer`.

| Class | Templates | Program | Solvers |
| :-- | :-- | :-- | :-- |
| quadratic | [`QuadraticTemplate`](@ref); [`SetProgTemplate`](@ref) with an ellipsoid | semidefinite | Clarabel, SCS, MOSEK |
| sum of squares | [`SumOfSquaresTemplate`](@ref); [`SetProgTemplate`](@ref) with a polynomial set | semidefinite | Clarabel, SCS, MOSEK |
| piecewise quadratic | [`SetProgTemplate`](@ref) with a piecewise ellipsoid | semidefinite | Clarabel, SCS, MOSEK |
| polyhedral | [`ParallelFacesPolyhedralTemplate`](@ref), [`ConicPolyhedralTemplate`](@ref); [`SetProgTemplate`](@ref) with a piecewise polytope | linear | HiGHS |
| copositive | [`LinearCopositiveTemplate`](@ref), [`DualCopositiveTemplate`](@ref) | linear | HiGHS |

A semidefinite solver such as Clarabel also solves the linear programs.

[What works with what](@ref) says which problems accept which template.

## Closure properties

A lift is **valid** for a template, guaranteed not to worsen the bound, when
the template is closed under the operation the lift combines node functions
with ([debauche2021comparison](@cite), Defs. 6 and 7): the sum lift needs
closure under addition, the min and max lifts under pointwise minimum and
maximum, the composition lifts under composition with the dynamics. A result of
[`compare`](@ref) holds for a template when the lift that gave it is valid for
the template. [`is_closed_under`](@ref) returns the closures of a template:

| Template | `+` | `max` | `min` | `∘ A` |
| :-- | :-: | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref) | ✓ | | | ✓ if invertible |
| [`SumOfSquaresTemplate`](@ref) | ✓ | | | ✓ if invertible |
| [`LinearCopositiveTemplate`](@ref) | ✓ | | valid on positive systems ¹ | ✓ if `A ≥ 0` with no zero column |
| [`DualCopositiveTemplate`](@ref) | | ✓ | | |
| [`ParallelFacesPolyhedralTemplate`](@ref) | | ✓ if the node matrices coincide | | |
| [`ConicPolyhedralTemplate`](@ref) | | | | |
| [`SetProgTemplate`](@ref) | ✓ if the nodes share the set variable | | | |

¹ Not closed as a set of functions, yet the min lift is valid for it on
positive linear systems ([debauche2024thesis](@cite), Thm. 7.43):
[`is_valid`](@ref) reads it through the dual template,
[`DualCopositiveTemplate`](@ref), closed under `max`.

Closure is a property of the template as implemented. Polyhedral norms are
closed under maximum, but the maximum of two members of the parallel-faces
template has the union of their facets, so that template is closed only when
every node has the same facet matrix. The free-facet template has a fixed
number of facets and declares no closure.

## Dual templates

[`has_dual`](@ref) tests whether a template has a dual, [`dual`](@ref)`(template)`
returns it, and `dual(template, V)` returns the dual norm of a fitted function
`V`. Quadratic forms are self-dual and the
copositive templates are each other's dual; the polyhedral, sum-of-squares and
SetProg templates have none here. A closure of one template of a dual pair is
used for both; see [Duality](@ref).

## Per-node data

The facet matrices of [`ParallelFacesPolyhedralTemplate`](@ref) and the set variables of
[`SetProgTemplate`](@ref) are attached to the nodes. When a refinement copies a
node, [`reindex`](@ref)`(template, origins)` gives the copy the data of the
node it came from.

## Writing your own

A new template implements the primitives listed in the
[developer conventions](@ref "Conventions"): its variables, the edge
inequality, and how a solution is read back. The problems need no change.
