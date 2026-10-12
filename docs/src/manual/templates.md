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

!!! warning "A template is an instance, never a type"
    Pass `QuadraticTemplate()`, not `QuadraticTemplate`. Some templates carry
    data, [`PolyhedralTemplate`](@ref) holds one matrix per node, and a type
    has nowhere to put it.

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

³ Behind a package extension: load SetProg first. An ellipsoid is the
quadratic template, a polynomial set the sum-of-squares one and a piecewise
polytope the free-facet one on the same cones; what it adds are the piecewise
semi-ellipsoids, quadratic on each cone of a partition, which improve on the
quadratic template as the partition is refined.

The **homogeneity degree**, [`homogeneity_degree`](@ref), is the ``d`` in
``V(cx) = c^d V(x)``. Stability scales its edge inequality by ``\gamma^d``, so
a rate means the same thing whatever the template, and bounds from different
templates compare. For safety the quadratic template is used in homogeneous
coordinates, ``[x; 1]^\top P_s [x; 1]``, without positive definiteness.

**Fixed or free facets.** [`PolyhedralTemplate`](@ref) fixes the facet
directions ``G_s`` and solves for the weights only, a linear program.
[`ConicPolyhedralTemplate`](@ref) solves for the facets as well: a larger
program, and a much less conservative one.

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
maximum, the composition lifts under composition with the dynamics. Which
lifts are valid for a template decides which verdicts of [`compare`](@ref)
hold for it. A template declares its closures with [`is_closed_under`](@ref):

| Template | `+` | `max` | `min` | `∘ A` |
| :-- | :-: | :-: | :-: | :-: |
| [`QuadraticTemplate`](@ref) | ✓ | | | ✓ if invertible |
| [`SumOfSquaresTemplate`](@ref) | ✓ | | | ✓ if invertible |
| [`LinearCopositiveTemplate`](@ref) | ✓ | | valid on positive systems ¹ | ✓ if `A ≥ 0` with no zero column |
| [`DualCopositiveTemplate`](@ref) | | ✓ | | |
| [`PolyhedralTemplate`](@ref) | | ✓ if the node matrices coincide | | |
| [`ConicPolyhedralTemplate`](@ref) | | | | |
| [`SetProgTemplate`](@ref) | | | | |

¹ Not closed as a set of functions, yet the min lift is valid for it on
positive linear systems ([debauche2024thesis](@cite), Thm. 7.43), the one
override of [`is_valid`](@ref).

Closure is a property of the family as implemented, not of the shape of its
functions. Polyhedral norms are closed under maximum, but the fixed-facet
template is only when every node shares the same facet matrix, since the
maximum of two of its members has the union of their facets; the free-facet
template declares nothing, because a maximum would need more facets than it
was given.

## A dual

[`has_dual`](@ref), [`dual`](@ref)`(template)` and `dual(template, V)`, the
dual norm of a fitted function. Quadratic forms are self-dual and the
copositive templates are each other's dual; the polyhedral, sum-of-squares and
SetProg templates have none here. A closure declared on either of a dual pair
serves both; see [Duality](@ref).

## Per-node data

A template whose data is attached to the nodes, such as the facet matrices of
[`PolyhedralTemplate`](@ref) or the set variables of [`SetProgTemplate`](@ref),
must say what a node copied by a refinement inherits. [`reindex`](@ref)`(template, origins)` gives every node of the new
graph the data of the node it came from; a data-free template returns itself.

## Writing your own

A new template is one file in `src/templates/catalogue/` implementing the
primitives of the template interface, listed in the
[developer conventions](@ref "Conventions"): how to create its
variables, state the edge inequality and read a solution back. Nothing in any
problem changes, and the three declarations above are optional, each
defaulting to claiming nothing.
