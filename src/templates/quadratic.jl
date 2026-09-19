import JuMP
import LinearAlgebra

"""
    QuadraticTemplate(; conditioning_bound = Inf)

The template ``V(x) = x^\\top P x``, with ``P`` positive definite.

`conditioning_bound` caps the conditioning of the fitted matrices,
``I \\preceq P_s \\preceq \\text{conditioning\\_bound} \\cdot I``. The lower half is
free — the edge conditions are homogeneous in ``P``, so ``P \\succeq I`` is only
a choice of scale — but **the cap is not**: it excludes certificates rather
than normalising them. A system whose only quadratic certificate needs
``\\operatorname{cond}(P)`` above the cap is then reported as having none, and
`is_stable` returns `false` for a stable system.

The default is therefore `Inf`, which imposes nothing. Set it only to help a
solver that is struggling, and read a negative answer as "no certificate within
this box" rather than "no certificate".
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

One fitted node function of a [`QuadraticTemplate`](@ref), `V(x) = x'Px`.

Only the *fitted* function is wrapped; while the model is being built the
template hands out the bare `Symmetric` matrix of variables, because problems do
matrix arithmetic with it — and because optimal control deliberately uses those
variables as the **inverse** of the node function, where calling the container a
`QuadraticFunction` would be a lie.

Wrapping the result is what makes node functions uniformly callable across
templates, so `node_value` is `V(x)` for all of them and the aggregation in
[`common`](@ref) needs to know nothing about which template it has.
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

function add_nonnegativity!(
    model::JuMP.Model,
    ::QuadraticTemplate,
    P::LinearAlgebra.Symmetric,
)
    JuMP.@constraint(model, P in JuMP.PSDCone())
    return nothing
end

solution_value(::QuadraticTemplate, P) = QuadraticFunction(JuMP.value.(P))

rate_exponent(::QuadraticTemplate) = 2

function add_normalization!(model::JuMP.Model, template::QuadraticTemplate, P)
    # Scale only: the edge conditions are homogeneous, so any feasible family
    # can be scaled until every member dominates I. This excludes P = 0 and
    # nothing else.
    JuMP.@constraint(model, P - LinearAlgebra.I in JuMP.PSDCone())

    # The cap is a genuine restriction, so it is opt-in. See the docstring.
    if isfinite(template.conditioning_bound)
        JuMP.@constraint(
            model,
            template.conditioning_bound * LinearAlgebra.I - P in JuMP.PSDCone()
        )
    end

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

node_value(
    ::QuadraticTemplate,
    ::AbstractProblem,
    V::QuadraticFunction,
    x::AbstractVector{<:Real},
) = V(x)
