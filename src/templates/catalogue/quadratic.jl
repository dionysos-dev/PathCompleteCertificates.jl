"""
    QuadraticTemplate()

The quadratic forms ``V(x) = x^\\top P x``, as the SetProg family
`Ellipsoid(symmetric = true)`. It applies to every system and every problem,
and gives semidefinite programs.

For stability, a fitted node function `V` is a SetProg ellipsoid: evaluate it
with [`node_value`](@ref), and read ``P`` as `V.Q`. The `conditioning_bound`
keyword of [`certify`](@ref) bounds ``P`` between ``I`` and
`conditioning_bound` times ``I``. Safety and optimal control return a
[`QuadraticFunction`](@ref) per node. See [Choosing a template](@ref).
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

The quadratic form ``V(z) = z^\\top P z``, a fitted node function of safety,
with ``z = [x; 1]``, and of optimal control, with ``z = x``. `Matrix(V)` is
``P``. Stability returns SetProg ellipsoids instead: see
[`QuadraticTemplate`](@ref).
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
