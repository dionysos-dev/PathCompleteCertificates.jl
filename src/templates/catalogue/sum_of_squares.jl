"""
    SumOfSquaresTemplate(degree; min_scale = 1, convex = false)

The sums of squares ``V(x) = \\sum_j q_j(x)^2``, each ``q_j`` a homogeneous
polynomial of degree `degree`, so that ``V`` has degree `2degree`,
as a normalized SetProg `PolySet` family; `degree = 1` gives the quadratic
forms. It applies to every system, for stability, safety and optimal control,
gives semidefinite programs, and needs `using SumOfSquares`. Polynomial
coordinates are created automatically from the system dimension.

Each node function is `min_scale * sum(x .^ 2)^degree` plus a sum of squares,
which excludes ``V \\equiv 0``. `convex = true` also makes each node function
convex, which optimal control requires, with a cost of degree `p = 2degree`.
[`refine`](@ref) does not run on this template: its edge slacks are not
implemented. See [Choosing a template](@ref).
"""
function SumOfSquaresTemplate(degree::Integer; min_scale::Real = 1, convex::Bool = false)
    degree >= 1 || throw(ArgumentError("degree must be at least 1, got $degree"))
    min_scale > 0 || throw(ArgumentError("min_scale must be positive"))
    family = SetProg.PolySet(; symmetric = true, convex, degree = 2 * Int(degree))
    return _NormalizedFamily(family, min_scale; contains_reference = false)
end
