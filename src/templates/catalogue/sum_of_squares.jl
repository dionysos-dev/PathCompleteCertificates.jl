"""
    SumOfSquaresTemplate(degree, variables; min_scale = 1e-3)

The template of polynomials ``V(x) = z(x)^\\top Q z(x)`` with ``Q \\succeq 0``,
where ``z`` runs over the monomials of degree `degree` in the polynomial
`variables`, shared by every node. `min_scale` is the lower bound on ``c`` in
``V(x) \\ge c \\|x\\|^{2\\,\\text{degree}}``. Requires `using SumOfSquares`.
[`decrease_slack`](@ref), hence [`edge_slacks`](@ref), is not implemented, so
[`refine`](@ref) does not run on it.
"""
struct SumOfSquaresTemplate{V <: AbstractVector, T <: Real} <: AbstractTemplate
    degree::Int
    variables::V
    min_scale::T

    function SumOfSquaresTemplate(
        degree::Integer,
        variables::V;
        min_scale::Real = 1e-3,
    ) where {V <: AbstractVector}
        degree >= 1 || throw(ArgumentError("degree must be at least 1, got $degree"))
        isempty(variables) && throw(ArgumentError("at least one variable is required"))
        min_scale > 0 || throw(ArgumentError("min_scale must be positive"))

        return new{V, typeof(min_scale)}(Int(degree), variables, min_scale)
    end
end

"""
    SumOfSquaresFunction(polynomial, variables)

A fitted node function of a [`SumOfSquaresTemplate`](@ref): a polynomial in
`variables`.
"""
struct SumOfSquaresFunction{P, V <: AbstractVector}
    polynomial::P
    variables::V
end

(V::SumOfSquaresFunction)(x::AbstractVector{<:Real}) =
    V.polynomial(V.variables => collect(x))

homogeneity_degree(template::SumOfSquaresTemplate) = 2 * template.degree

is_closed_under(::SumOfSquaresTemplate, ::Addition, system) = true
is_closed_under(::SumOfSquaresTemplate, ::Composition, system) = is_invertible(system)
is_closed_under(::SumOfSquaresTemplate, ::InverseComposition, system) =
    is_invertible(system)
