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
| [`PolyhedralTemplate`](@ref) | ``\max_k \lvert (G_s x)_k \rvert / w_{s,k}`` | 1 | weights ``w_s``, facets ``G_s`` fixed | [athanasopoulos2019polyhedral](@cite) |
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

**Fixed or free facets.** [`PolyhedralTemplate`](@ref) fixes the facet
directions ``G_s`` and solves for the weights only, a linear program.
[`ConicPolyhedralTemplate`](@ref) solves for the facets as well: a larger
program, and a less conservative one.

**The two copositive templates** are each other's duals, the dual norm of
``c^\top x`` on the orthant being ``\max_i x_i / c_i``. Both are defined on
the nonnegative orthant, so they apply to positive systems only;
[`check_dynamics`](@ref) throws on any other.

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
| [`PolyhedralTemplate`](@ref) | | ✓ if the node matrices coincide | | |
| [`ConicPolyhedralTemplate`](@ref) | | | | |
| [`SetProgTemplate`](@ref) | ✓ if the nodes share the set variable | | | |

¹ Not closed as a set of functions, yet the min lift is valid for it on
positive linear systems ([debauche2024thesis](@cite), Thm. 7.43), the one
override of [`is_valid`](@ref).

Closure is a property of the template as implemented. Polyhedral norms are
closed under maximum, but the maximum of two members of the fixed-facet
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

The facet matrices of [`PolyhedralTemplate`](@ref) and the set variables of
[`SetProgTemplate`](@ref) are attached to the nodes. When a refinement copies a
node, [`reindex`](@ref)`(template, origins)` gives the copy the data of the
node it came from.

## Writing your own

A new template implements the primitives listed in the
[developer conventions](@ref "Conventions"): its variables, the edge
inequality, and how a solution is read back. The problems need no change.
