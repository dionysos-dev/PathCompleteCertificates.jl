"""
    SetProgTemplate(variable)
    SetProgTemplate(variables::AbstractVector)

The template whose node function ``V_s`` has as 1-sublevel set a
[SetProg](https://github.com/blegat/SetProg.jl) set ``S_s``; the edge inequality
is the inclusion ``(A / \\gamma) S_{src} \\subseteq S_{dst}``. `variable` is one of

| `variable` | ``V_s(x)`` | Degree |
| :-- | :-- | :-: |
| `Ellipsoid(symmetric = true)` | ``x^\\top Q_s x`` | 2 |
| `PolySet(symmetric = true, degree = 2d, variables = x)` | a polynomial ``p_s(x)`` | ``2d`` |
| `Ellipsoid(symmetric = true, piecewise = P)` | ``x^\\top Q_{s,i} x`` on the ``i``th cone | 2 |
| `Polytope(symmetric = true, piecewise = P)` | ``a_{s,i}^\\top x`` on the ``i``th cone | 1 |

where the cones are over the facets of the polytope `P`, which must contain
the origin in its interior. A vector gives one variable per node.

Requires `using SetProg`. Round the facet normals of `P`, since rounding errors
can make an almost optimal solution violate the edge inequalities, and build
`P` with a simplex solver such as HiGHS for speed. [`domination_slack`](@ref),
hence [`edge_slacks`](@ref), is not implemented.
"""
struct SetProgTemplate{V <: AbstractVector} <: AbstractTemplate
    variables::V
    shared::Bool

    SetProgTemplate(variables::AbstractVector) = new{typeof(variables)}(variables, false)
    SetProgTemplate(variable) = new{Vector{typeof(variable)}}([variable], true)
end

"""
    SetProgFunction(set)

A fitted node function of a [`SetProgTemplate`](@ref), whose 1-sublevel set
is `set`.
"""
struct SetProgFunction{S}
    set::S
end

reindex(template::SetProgTemplate, origins::AbstractVector) =
    template.shared ? template :
    SetProgTemplate(_reindexed_data(template.variables, origins, "set variables"))

# The sets are built in their cone (PSD matrices, SOS polynomials).
add_nonnegativity!(::JuMP.Model, ::SetProgTemplate, _) = nothing

# Closed under addition when all nodes share one family and one partition.
is_closed_under(template::SetProgTemplate, ::Addition, system) =
    template.shared || allequal(template.variables)
