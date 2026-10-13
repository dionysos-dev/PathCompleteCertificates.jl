"""
    SumOfSquaresTemplate(degree, variables)

The template of polynomials ``V(x) = z(x)^\\top Q z(x)`` with ``Q \\succeq 0``,
where ``z`` runs over the monomials of degree `degree` in the polynomial
`variables`, shared by every node. Requires `using SumOfSquares`.
"""
struct SumOfSquaresTemplate{V <: AbstractVector} <: AbstractTemplate
    degree::Int
    variables::V

    function SumOfSquaresTemplate(degree::Integer, variables::V) where {V <: AbstractVector}
        degree >= 1 || throw(ArgumentError("degree must be at least 1, got $degree"))
        isempty(variables) && throw(ArgumentError("at least one variable is required"))

        return new{V}(Int(degree), variables)
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

# A `SOSPoly` variable is nonnegative by construction.
add_nonnegativity!(::JuMP.Model, ::SumOfSquaresTemplate, _) = nothing

is_closed_under(::SumOfSquaresTemplate, ::Addition, system) = true
is_closed_under(::SumOfSquaresTemplate, ::Composition, system) = is_invertible(system)
is_closed_under(::SumOfSquaresTemplate, ::InverseComposition, system) =
    is_invertible(system)
