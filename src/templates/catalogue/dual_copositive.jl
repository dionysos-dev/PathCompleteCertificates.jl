import JuMP
import LinearAlgebra

"""
    DualCopositiveTemplate(; min_weight = 1e-3)

The template ``V(x) = \\max_i x_i / v_i`` on the nonnegative orthant, with
every ``v_i`` at least `min_weight`: the dual of
[`LinearCopositiveTemplate`](@ref). For positive systems only.
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

A node function `V(x) = max_i x_i / v_i` of a [`DualCopositiveTemplate`](@ref).
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

homogeneity_degree(::DualCopositiveTemplate) = 1

# The lower bound min_weight on v already excludes V = 0.
add_normalization!(::JuMP.Model, ::DualCopositiveTemplate, ::DualCopositiveFunction) =
    nothing

function add_decrease!(
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

function decrease_slack(
    ::DualCopositiveTemplate,
    V_src::DualCopositiveFunction,
    V_dst::DualCopositiveFunction,
    map::AbstractMatrix;
    scale = 1,
)
    return minimum(scale * V_dst.v - map * V_src.v)
end

# max(V_v, V_w) = V_min(v, w) [debauche2021comparison, Prop. 5].
is_closed_under(::DualCopositiveTemplate, ::Maximum, system) = true

has_dual(::DualCopositiveTemplate) = true
dual(::DualCopositiveTemplate) = LinearCopositiveTemplate()
dual(::DualCopositiveTemplate, V::DualCopositiveFunction) = LinearCopositiveFunction(V.v)
