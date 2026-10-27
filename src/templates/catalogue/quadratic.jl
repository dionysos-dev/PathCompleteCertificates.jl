"""
    QuadraticTemplate()

Return `SetProg.Ellipsoid(symmetric = true)`, the native family of homogeneous
quadratic gauges. Stability returns fitted SetProg ellipsoids; evaluate them
with `node_value(problem, V, x)` and access their matrices as `V.Q`.
Use the `conditioning_bound` keyword of `certify` to cap the
coefficient matrix. Safety and optimal control retain their matrix models.
"""
function QuadraticTemplate()
    return SetProg.Ellipsoid(; symmetric = true)
end

# Private matrix builder for the deferred safety and optimal-control models.
struct _QuadraticTemplate end

function _legacy_quadratic(template, problem)
    template == QuadraticTemplate() || throw(
        ArgumentError(
            "$(nameof(typeof(problem))) currently supports only QuadraticTemplate()",
        ),
    )
    return _QuadraticTemplate()
end

"""
    QuadraticFunction(P)

A fitted quadratic `V(x) = x'Px`, used by safety and optimal control.
`Matrix(V)` is `P`. Stability returns native SetProg ellipsoids instead.
"""
struct QuadraticFunction{M <: AbstractMatrix}
    P::M
end

(V::QuadraticFunction)(x::AbstractVector{<:Real}) = LinearAlgebra.dot(x, V.P * x)

Base.Matrix(V::QuadraticFunction) = Matrix(V.P)

function add_function_variables!(
    model::JuMP.Model,
    ::_QuadraticTemplate,
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

solution_value(::_QuadraticTemplate, P) = QuadraticFunction(JuMP.value.(P))

function add_decrease!(
    model::JuMP.Model,
    ::_QuadraticTemplate,
    P_src::LinearAlgebra.Symmetric,
    P_dst::LinearAlgebra.Symmetric,
    map::AbstractMatrix;
    scale = 1,
)
    JuMP.@constraint(model, scale * P_src - transpose(map) * P_dst * map in JuMP.PSDCone())

    return nothing
end

function decrease_slack(
    ::SetProg.Ellipsoid,
    V_src::QuadraticFunction,
    V_dst::QuadraticFunction,
    map::AbstractMatrix;
    scale = 1,
)
    residual = scale * V_src.P - transpose(map) * V_dst.P * map

    return minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(Matrix(residual))))
end
