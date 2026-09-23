"""
    SumOfSquaresTemplate(degree, variables)

The template of polynomials ``V(x) = z(x)^\\top Q z(x)`` with ``Q \\succeq 0``,
where ``z`` runs over the monomials of degree `degree`. Node functions are
therefore sums of squares, homogeneous of degree ``2\\,`` `degree`.

`variables` are the polynomial variables the node functions are written in, and
**every node shares them** — an edge inequality relates two node functions, so
they have to live in the same ring. Create them once and pass them in:

```julia
using SumOfSquares, DynamicPolynomials   # both, and before this is usable
@polyvar x[1:2]
template = SumOfSquaresTemplate(2, x)    # quartic node functions on the plane
```

!!! note "The methods live in a package extension"
    Everything this template does is behind `SumOfSquares`, which pulls a large
    polynomial stack. Without `using SumOfSquares` the type exists but its
    primitives are not defined, and a solve fails with a `MethodError` naming
    one of them.

`degree = 1` recovers the quadratic template, more expensively:
[`QuadraticTemplate`](@ref) writes the same cone directly. Raise the degree to
certify a rate that no quadratic can — the price is a Gram matrix of size
``\\binom{n + d - 1}{d}`` per node.
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

A fitted [`SumOfSquaresTemplate`](@ref) node function: the solved polynomial,
plus the variables to substitute into. Callable, like every node function.
"""
struct SumOfSquaresFunction{P, V <: AbstractVector}
    polynomial::P
    variables::V
end

(V::SumOfSquaresFunction)(x::AbstractVector{<:Real}) =
    V.polynomial(V.variables => collect(x))

rate_exponent(template::SumOfSquaresTemplate) = 2 * template.degree

# A `SOSPoly` variable is a Gram matrix constrained positive semidefinite, so
# the node function is nonnegative by construction and there is nothing to add.
add_nonnegativity!(::JuMP.Model, ::SumOfSquaresTemplate, _) = nothing

node_value(
    ::SumOfSquaresTemplate,
    ::AbstractProblem,
    V::SumOfSquaresFunction,
    x::AbstractVector{<:Real},
) = V(x)
