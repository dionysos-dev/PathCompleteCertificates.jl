import JuMP
import LinearAlgebra

"""
    LinearCopositiveTemplate()

The template ``V(x) = c^\\top x`` on the nonnegative orthant.  It is applicable
to positive switched systems only: every mode matrix must map ``\\mathbb{R}^n_+``
into itself.
"""
struct LinearCopositiveTemplate <: AbstractTemplate end

function add_function_variables!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return JuMP.@variable(model, [1:dimension], base_name = "c_$(node)")
end

function add_nonnegativity!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    c::AbstractVector,
)
    JuMP.@constraint(model, c .>= 0)
    return nothing
end

solution_value(::LinearCopositiveTemplate, c) = JuMP.value.(c)

rate_exponent(::LinearCopositiveTemplate) = 1

function add_normalization!(model::JuMP.Model, ::LinearCopositiveTemplate, c)
    JuMP.@constraint(model, c .>= 1)

    return nothing
end

function add_domination!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    c_src,
    c_dst,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    # On the nonnegative orthant the gauge is linear, so the margin term
    # `margin * ||x||_1 = margin * sum(x)` is linear too and costs nothing.
    JuMP.@constraint(model, transpose(map) * c_dst .<= scale * c_src .- margin)

    return nothing
end

node_value(::LinearCopositiveTemplate, ::AbstractProblem, c, x::AbstractVector{<:Real}) =
    LinearAlgebra.dot(c, x)

function check_dynamics(::LinearCopositiveTemplate, A::AbstractVector{<:AbstractMatrix})
    any(A_i -> any(<(0), A_i), A) && throw(
        ArgumentError(
            "LinearCopositiveTemplate requires entrywise nonnegative matrices: " *
            "V(x) = c'x certifies nothing about a system that leaves the " *
            "nonnegative orthant",
        ),
    )

    return nothing
end

function domination_slack(
    ::LinearCopositiveTemplate,
    c_src::AbstractVector,
    c_dst::AbstractVector,
    map::AbstractMatrix;
    scale = 1,
)
    return minimum(scale * c_src - transpose(map) * c_dst)
end
