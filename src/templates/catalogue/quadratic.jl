"""
    QuadraticTemplate()

The quadratic forms ``V(x) = x^\\top P x``, as the SetProg family
`Ellipsoid(symmetric = true)`. It applies to every system and every problem,
and gives semidefinite programs.

For stability, a fitted node function `V` is a SetProg ellipsoid: evaluate it
with [`node_value`](@ref), and read ``P`` as `V.Q`. The `conditioning_bound`
keyword of [`certify`](@ref) bounds ``P`` between ``I`` and
`conditioning_bound` times ``I``. Safety returns affine SetProg quadratics;
optimal control returns a [`QuadraticFunction`](@ref) per node.
See [Choosing a template](@ref).
"""
function QuadraticTemplate()
    return SetProg.Ellipsoid(; symmetric = true)
end

"""
    QuadraticFunction(P)

The quadratic form ``V(x) = x^\\top P x``, a fitted node function of optimal
control. `Matrix(V)` is ``P``. Stability and safety return native SetProg sets
instead: see [`QuadraticTemplate`](@ref).
"""
struct QuadraticFunction{M <: AbstractMatrix}
    P::M
end

(V::QuadraticFunction)(x::AbstractVector{<:Real}) = LinearAlgebra.dot(x, V.P * x)

Base.Matrix(V::QuadraticFunction) = Matrix(V.P)

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
