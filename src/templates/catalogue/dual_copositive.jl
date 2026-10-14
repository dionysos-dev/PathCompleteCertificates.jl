"""
    DualCopositiveTemplate(; min_weight = 1)

The template ``V(x) = \\max_i x_i / v_i`` on the nonnegative orthant, with
every ``v_i`` at least `min_weight`: the dual of
[`LinearCopositiveTemplate`](@ref). For positive systems only. The program is
homogeneous, so `min_weight` only fixes its scale; a much smaller one lets the
solver's absolute tolerance show in the rate.
"""
struct DualCopositiveTemplate{T <: Real} <: AbstractTemplate
    min_weight::T

    function DualCopositiveTemplate(; min_weight::Real = 1)
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

# The weights are a denominator, so they are bounded away from zero.
function add_function_variables!(
    model::JuMP.Model,
    template::DualCopositiveTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    v = JuMP.@variable(
        model,
        [1:dimension],
        lower_bound = template.min_weight,
        base_name = "v_$(node)",
    )
    return DualCopositiveFunction(v)
end

solution_value(::DualCopositiveTemplate, V::DualCopositiveFunction) =
    DualCopositiveFunction(JuMP.value.(V.v))

homogeneity_degree(::DualCopositiveTemplate) = 1

# The bounded weights already make V positive on the orthant.
add_normalization!(::JuMP.Model, ::DualCopositiveTemplate, ::DualCopositiveFunction) =
    nothing

function add_decrease!(
    model::JuMP.Model,
    ::DualCopositiveTemplate,
    V_src::DualCopositiveFunction,
    V_dst::DualCopositiveFunction,
    map::AbstractMatrix;
    scale = 1,
)
    # V_dst(A x) ≤ scale · V_src(x) for every x ≥ 0 is A v_src ≤ scale · v_dst.
    JuMP.@constraint(model, map * V_src.v .<= scale * V_dst.v)

    return nothing
end

# On the orthant only: a positive system never leaves it.
is_applicable(::DualCopositiveTemplate, system) = is_positive(system)

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
