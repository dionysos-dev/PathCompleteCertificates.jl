"""
    SumOfSquaresTemplate(degree, variables; min_scale = 1)

Construct a native SetProg `PolySet` of homogeneous SOS polynomials of degree
`2degree`, using the shared polynomial `variables`. Its gauge is
`min_scale * sum(variables .^ 2)^degree` plus an SOS remainder, so `min_scale`
fixes the normalization. Requires `using SumOfSquares`.
Decrease slacks and refinement are not implemented for polynomial sets.
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
