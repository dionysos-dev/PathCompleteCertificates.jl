```@meta
CurrentModule = PathCompleteCertificates
```

# Templates

A template is the **family** the node functions are drawn from.
[`solution_value`](@ref) turns a solved template into the fitted, callable
member.

!!! warning "A template is an instance, never a type"
    Pass `QuadraticTemplate()`, not `QuadraticTemplate`. Some templates carry
    data, [`PolyhedralTemplate`](@ref) holds one matrix per node, and a type
    has nowhere to put it.

## The six templates

| Template | ``V_s(x)`` | Degree | Solved for | Source |
| :-- | :-- | :-: | :-- | :-- |
| [`QuadraticTemplate`](@ref) | ``x^\top P_s x`` | 2 | ``P_s \succ 0`` | standard |
| [`LinearCopositiveTemplate`](@ref) | ``c_s^\top x`` on the nonnegative orthant | 1 | ``c_s > 0`` | standard |
| [`DualCopositiveTemplate`](@ref) | ``\max_i x_i / v_{s,i}`` on the nonnegative orthant | 1 | ``v_s > 0`` | [debauche2024thesis](@cite), Def. 2.30 |
| [`PolyhedralTemplate`](@ref) | ``\max_k \lvert (G_s x)_k \rvert / w_{s,k}`` | 1 | weights ``w_s`` | [athanasopoulos2019polyhedral](@cite) |
| [`ConicPolyhedralTemplate`](@ref) | ``\max_i \lvert p_{s,i}^\top x \rvert`` | 1 | facets ``p_{s,i}`` | unpublished ¹ |
| [`SumOfSquaresTemplate`](@ref) | ``z(x)^\top Q_s z(x)`` | ``2d`` | ``Q_s \succeq 0`` | [parrilo2008approximation](@cite) ² |

¹ The free-facet construction is not yet published; it is under submission.

² Behind a package extension, since it pulls in the whole polynomial stack.
Raising `d` tightens the bound monotonically, and `d = 1` is exactly
[`QuadraticTemplate`](@ref), a useful thing to check a change against.

The degree is [`rate_exponent`](@ref): ``V(cx) = c^d V(x)``. It is accounted
for when rates are computed, so bounds from different templates are
comparable.

**The two polyhedral templates** differ in what is fixed.
[`PolyhedralTemplate`](@ref) fixes the facet directions and solves only for the
weights, keeping the program linear. [`ConicPolyhedralTemplate`](@ref) solves
for the facets too: larger, and much less conservative. On a rotation scaled by
`0.9` the fixed-facet template certifies nothing while the conic one reaches
`0.901`.

**The two copositive templates** are each other's duals: the dual norm of
``c^\top x`` on the orthant is ``\max_i x_i / c_i``. The primal family is
closed under addition, the dual one under pointwise maximum, which is the
cheapest pair on which a lift is valid for one template and not the other.

!!! note "Not every template suits every system"
    The copositive templates need entrywise nonnegative mode matrices;
    ``c^\top x`` certifies nothing about a system that leaves the nonnegative
    orthant. [`check_dynamics`](@ref) throws rather than returning a
    meaningless bound.

See [What works with what](@ref) for which problems accept which template.

## What a template declares beyond its functions

Three declarations make a template usable by the graph layer. Each has a
default that claims nothing, so a template that declares none can still be
lifted and compared; it just carries no guarantee.

- **Closures.** [`is_closed_under`](@ref)`(template, operation, system)` for
  the five [`Operation`](@ref)s: [`Addition`](@ref), [`Maximum`](@ref),
  [`Minimum`](@ref), [`Composition`](@ref) with the dynamics and
  [`InverseComposition`](@ref). They decide which lifts are *valid* for the
  template and which procedure decides the order between two graphs. The table
  of what each template declares is on the [Lifts](@ref) page.
- **A dual.** [`has_dual`](@ref), [`dual`](@ref)`(template)` and
  `dual(template, V)`, the dual norm of a fitted function. Quadratic forms are
  self-dual and the copositive templates are each other's dual; the polyhedral
  and sum-of-squares templates have none here. See [Duality](@ref).
- **Per-node data.** A template carrying something per node, such as the
  facet matrices of [`PolyhedralTemplate`](@ref), follows a lifted graph
  through [`reindex`](@ref), which hands each new node the data of the node it
  came from.

## Writing your own

One file, answering a handful of primitives. No change to any problem, so it
works with every problem that accepts it, and the three declarations above
are optional. The interfaces are in the
[developer conventions](@ref "Coding conventions").
