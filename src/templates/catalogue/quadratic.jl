"""
    QuadraticTemplate(; conditioning_bound = Inf)

Legacy quadratic node functions for safety and optimal control. Stability
uses `SetProg.Ellipsoid(symmetric = true)` directly instead.
Safety evaluates the quadratic in homogeneous coordinates and permits an
indefinite coefficient matrix; optimal control uses positive quadratic forms.
The `conditioning_bound` parameter is retained for the legacy normalization
primitive.

"""
struct QuadraticTemplate{T <: Real} <: AbstractTemplate
    conditioning_bound::T

    function QuadraticTemplate(; conditioning_bound::Real = Inf)
        conditioning_bound >= 1 || throw(
            ArgumentError(
                "conditioning_bound must be at least 1, since the normalization " *
                "already imposes P >= I",
            ),
        )

        return new{typeof(conditioning_bound)}(conditioning_bound)
    end
end

"""
    QuadraticFunction(P)

A fitted node function `V(x) = x'Px` of a [`QuadraticTemplate`](@ref);
`Matrix(V)` is `P`.
"""
struct QuadraticFunction{M <: AbstractMatrix}
    P::M
end

(V::QuadraticFunction)(x::AbstractVector{<:Real}) = LinearAlgebra.dot(x, V.P * x)

Base.Matrix(V::QuadraticFunction) = Matrix(V.P)

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

solution_value(::QuadraticTemplate, P) = QuadraticFunction(JuMP.value.(P))

homogeneity_degree(::QuadraticTemplate) = 2

function add_normalization!(model::JuMP.Model, template::QuadraticTemplate, P)
    # The edge conditions are homogeneous, so this only fixes the scale.
    JuMP.@constraint(model, P - LinearAlgebra.I in JuMP.PSDCone())

    if isfinite(template.conditioning_bound)
        JuMP.@constraint(
            model,
            template.conditioning_bound * LinearAlgebra.I - P in JuMP.PSDCone()
        )
    end

    return nothing
end

function add_decrease!(
    model::JuMP.Model,
    ::QuadraticTemplate,
    P_src::LinearAlgebra.Symmetric,
    P_dst::LinearAlgebra.Symmetric,
    map::AbstractMatrix;
    scale = 1,
)
    JuMP.@constraint(model, scale * P_src - transpose(map) * P_dst * map in JuMP.PSDCone())

    return nothing
end

function decrease_slack(
    ::QuadraticTemplate,
    V_src::QuadraticFunction,
    V_dst::QuadraticFunction,
    map::AbstractMatrix;
    scale = 1,
)
    residual = scale * V_src.P - transpose(map) * V_dst.P * map

    return minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(Matrix(residual))))
end

# AᵀPA is positive definite only when A is invertible.
is_closed_under(::QuadraticTemplate, ::Addition, system) = true
is_closed_under(::QuadraticTemplate, ::Composition, system) = _is_invertible(system)
is_closed_under(::QuadraticTemplate, ::InverseComposition, system) = _is_invertible(system)

# The dual norm of xᵀPx is xᵀP⁻¹x, and the conditioning box is self-dual.
has_dual(::QuadraticTemplate) = true
dual(template::QuadraticTemplate) = template
dual(::QuadraticTemplate, V::QuadraticFunction) = QuadraticFunction(inv(V.P))
