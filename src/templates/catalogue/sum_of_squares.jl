"""
    SumOfSquaresTemplate(degree, variables; min_scale = 1)

The sums of squares ``V(x) = \\sum_j q_j(x)^2``, each ``q_j`` a homogeneous
polynomial of degree `degree` in the polynomial `variables`, so that ``V`` has
degree `2degree`, as a SetProg `PolySet`; `degree = 1` gives the quadratic
forms. It applies to every system, for stability, gives semidefinite programs,
and needs `using SumOfSquares`.

Each node function is `min_scale * sum(x .^ 2)^degree` plus a sum of squares,
which excludes ``V \\equiv 0``. [`refine`](@ref) does not run on this template:
its edge slacks are not implemented. See [Choosing a template](@ref).
"""
function SumOfSquaresTemplate(
    degree::Integer,
    variables::AbstractVector;
    min_scale::Real = 1,
)
    degree >= 1 || throw(ArgumentError("degree must be at least 1, got $degree"))
    isempty(variables) && throw(ArgumentError("at least one variable is required"))
    min_scale > 0 || throw(ArgumentError("min_scale must be positive"))
    family = SetProg.PolySet(; symmetric = true, degree = 2 * Int(degree), variables)
    return _with_superset(family, _unit_set(family; scale = min_scale))
end
