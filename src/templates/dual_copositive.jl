import JuMP
import LinearAlgebra

"""
    DualCopositiveTemplate(; min_weight = 1e-3)

The template ``V(x) = \\max_i x_i / v_i`` on the nonnegative orthant, with
``v > 0``: the dual norms of [`LinearCopositiveTemplate`](@ref), and what
`dual(LinearCopositiveTemplate())` returns (Debauche, Della Rossa & Jungers,
Def. 11).

Applicable to positive switched systems only, like its dual. The edge condition
``V_{dst}(Ax) ≤ γ V_{src}(x)`` on the orthant is ``A v_{src} ≤ γ v_{dst}``
componentwise (their Prop. 5), so every program stays linear.

Closed under pointwise maximum — ``\\max(V_v, V_w) = V_{\\min(v, w)}`` — which the
primal template is not; the two are the cheapest pair on which a lift is valid
for one template and not the other.

`min_weight` floors the weights, which sit in a denominator; it also normalises,
the edge conditions being homogeneous.
"""
struct DualCopositiveTemplate{T <: Real} <: AbstractTemplate
    min_weight::T

    function DualCopositiveTemplate(; min_weight::Real = 1e-3)
        min_weight > 0 || throw(ArgumentError("min_weight must be positive"))
        return new{typeof(min_weight)}(min_weight)
    end
end

"""
    DualCopositiveFunction(v)

One fitted node function of a [`DualCopositiveTemplate`](@ref),
`V(x) = max_i x_i / v_i`.
"""
struct DualCopositiveFunction{W <: AbstractVector}
    v::W
end

(V::DualCopositiveFunction)(x::AbstractVector{<:Real}) = maximum(x ./ V.v)

function add_function_variables!(
    model::JuMP.Model,
    ::DualCopositiveTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return DualCopositiveFunction(
        JuMP.@variable(model, [1:dimension], base_name = "v_$(node)")
    )
end

function add_nonnegativity!(
    model::JuMP.Model,
    template::DualCopositiveTemplate,
    V::DualCopositiveFunction,
)
    JuMP.@constraint(model, V.v .>= template.min_weight)
    return nothing
end

solution_value(::DualCopositiveTemplate, V::DualCopositiveFunction) =
    DualCopositiveFunction(JuMP.value.(V.v))

rate_exponent(::DualCopositiveTemplate) = 1

# The floor on the weights is the normalisation: the edge conditions are
# homogeneous in v.
add_normalization!(::JuMP.Model, ::DualCopositiveTemplate, ::DualCopositiveFunction) =
    nothing

function add_domination!(
    model::JuMP.Model,
    ::DualCopositiveTemplate,
    V_src::DualCopositiveFunction,
    V_dst::DualCopositiveFunction,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    margin == 0 || throw(
        ArgumentError(
            "DualCopositiveTemplate cannot express a margin: the weights sit in a " *
            "denominator, so the margin term is not linear in them",
        ),
    )

    # V_dst(A x) ≤ scale · V_src(x) for every x ≥ 0 is A v_src ≤ scale · v_dst.
    JuMP.@constraint(model, map * V_src.v .<= scale * V_dst.v)

    return nothing
end

node_value(
    ::DualCopositiveTemplate,
    ::AbstractProblem,
    V::DualCopositiveFunction,
    x::AbstractVector{<:Real},
) = V(x)

function check_dynamics(::DualCopositiveTemplate, A::AbstractVector{<:AbstractMatrix})
    any(A_i -> any(<(0), A_i), A) && throw(
        ArgumentError(
            "DualCopositiveTemplate requires entrywise nonnegative matrices: " *
            "max_i x_i / v_i certifies nothing about a system that leaves the " *
            "nonnegative orthant",
        ),
    )

    return nothing
end

function domination_slack(
    ::DualCopositiveTemplate,
    V_src::DualCopositiveFunction,
    V_dst::DualCopositiveFunction,
    map::AbstractMatrix;
    scale = 1,
)
    return minimum(scale * V_dst.v - map * V_src.v)
end

# Prop. 5 of Debauche, Della Rossa & Jungers: the maximum of two dual norms is
# the dual norm of the componentwise minimum.
is_closed_under(::DualCopositiveTemplate, ::Maximum, system) = true

dual(::DualCopositiveTemplate) = LinearCopositiveTemplate()
