"""
    SetProgTemplate(variable)
    SetProgTemplate(variables::AbstractVector)

The template of the sets of [SetProg](https://github.com/blegat/SetProg.jl):
node ``s`` carries a set ``S_s`` and its node function is the gauge-like
function ``V_s`` whose 1-sublevel set is ``S_s``. For homogeneous functions of
degree ``d``, the edge inequality ``V_{dst}(A x) \\le \\gamma^d V_{src}(x)`` is
the set inclusion ``(A / \\gamma) S_{src} \\subseteq S_{dst}``, which is what
this template asks SetProg for.

`variable` is a SetProg set variable, one of

| `variable` | ``V_s(x)`` | Degree |
| :-- | :-- | :-: |
| `Ellipsoid(symmetric = true)` | ``x^\\top Q_s x`` | 2 |
| `PolySet(symmetric = true, degree = 2d, variables = x)` | a polynomial ``p_s(x)`` | ``2d`` |
| `Ellipsoid(symmetric = true, piecewise = P)` | ``x^\\top Q_{s,i} x`` on the ``i``th cone | 2 |
| `Polytope(symmetric = true, piecewise = P)` | ``a_{s,i}^\\top x`` on the ``i``th cone | 1 |

The piecewise ones are what this template adds to the others: a piecewise
semi-ellipsoid, or a polytope, whose function is quadratic, or linear, on each
cone over a facet of the polytope `P` (which must contain the origin in its
interior). Pass a vector with one variable per node to give each node its own
partition.

```julia
using SetProg   # before this is usable
template = SetProgTemplate(Ellipsoid(symmetric = true, piecewise = P))
```

The node functions are normalized by ``V_s(x) \\ge \\lVert x \\rVert_2^d``,
where ``d`` is the degree, or by ``V_s(x) \\ge`` the gauge of `P` for a
polytope. The edge conditions are homogeneous, so this only fixes the scale.

!!! note "The methods live in a package extension"
    Everything this template does is behind `SetProg`, which pulls the
    polynomial and polyhedral stacks. Without `using SetProg` the type exists
    but its primitives are not defined.

!!! warning "Use a partition with exact facets"
    Rounding errors in the facet normals of `P`, such as the `1e-16` of a
    `cos(π / 2)`, can make the solver report an almost optimal solution that
    violates the edge inequalities. Round the normals, or use exact numbers.

Build `P` with a Polyhedra library whose solver is a simplex one, such as
HiGHS: SetProg runs many small linear programs on the partition at every
solve, and an interior-point solver makes each of them slow.

[`domination_slack`](@ref) is not implemented for this template, so neither
are [`edge_slacks`](@ref) and what builds on it.
"""
struct SetProgTemplate{V <: AbstractVector} <: AbstractTemplate
    variables::V
    shared::Bool

    SetProgTemplate(variables::AbstractVector) = new{typeof(variables)}(variables, false)
    SetProgTemplate(variable) = new{Vector{typeof(variable)}}([variable], true)
end

"""
    SetProgFunction(set)

A fitted [`SetProgTemplate`](@ref) node function: the solved SetProg set,
callable as ``V(x)``, the function whose 1-sublevel set is `set`.
"""
struct SetProgFunction{S}
    set::S
end

# A shared variable follows any lift. One per node gives each new node the
# variable of its origin.
reindex(template::SetProgTemplate, origins::AbstractVector) =
    template.shared ? template :
    SetProgTemplate(_reindexed_data(template.variables, origins, "set variables"))

# The sets are constructed in their cone (PSD matrices, SOS polynomials), and
# the normalization keeps them positive, so there is nothing to add.
add_nonnegativity!(::JuMP.Model, ::SetProgTemplate, _) = nothing

# The sum of two functions of one family, on one partition, is in the family
# again: closed under addition exactly when every node carries the same set
# variable, as the fixed-facet polyhedral template is under maximum.
is_closed_under(template::SetProgTemplate, ::Addition, system) =
    template.shared || allequal(template.variables)
