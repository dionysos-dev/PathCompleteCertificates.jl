import JuMP
import LinearAlgebra

raw"""
    QuadraticTemplate()

The template ``V(x) = x^\top P x``, with ``P`` positive definite.
"""
struct QuadraticTemplate <: AbstractTemplate end

function add_function_variables!(
    model::JuMP.Model,
    ::QuadraticTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return JuMP.@variable(
        model,
        [1:dimension, 1:dimension],
        Symmetric,
        base_name = "P_$(node)",
    )
end

function add_nonnegativity!(
    model::JuMP.Model,
    ::QuadraticTemplate,
    P::LinearAlgebra.Symmetric,
)
    JuMP.@constraint(model, P in JuMP.PSDCone())
    return nothing
end

solution_value(::QuadraticTemplate, P) = JuMP.value.(P)

rate_exponent(::QuadraticTemplate) = 2

function _add_normalization!(model::JuMP.Model, ::QuadraticTemplate, P)
    JuMP.@constraint(model, P - LinearAlgebra.I in JuMP.PSDCone())

    # An upper bound on the conditioning, for numerical conditioning only. It
    # is a real restriction: a system whose only quadratic certificate needs
    # cond(P) > 100 is reported as having none.
    JuMP.@constraint(model, 100 * LinearAlgebra.I - P in JuMP.PSDCone())

    return nothing
end

function add_domination!(
    model::JuMP.Model,
    ::QuadraticTemplate,
    P_src::LinearAlgebra.Symmetric,
    P_dst::LinearAlgebra.Symmetric,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    dimension = size(map, 1)

    JuMP.@constraint(
        model,
        scale * P_src - transpose(map) * P_dst * map -
        margin * LinearAlgebra.I(dimension) in JuMP.PSDCone()
    )

    return nothing
end

_node_value(::QuadraticTemplate, ::AbstractProblem, P, x::AbstractVector{<:Real}) =
    LinearAlgebra.dot(x, P * x)
