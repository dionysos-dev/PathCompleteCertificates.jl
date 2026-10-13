"""
    LinearCopositiveTemplate()

The template ``V(x) = c^\\top x`` on the nonnegative orthant, for positive
systems only.
"""
struct LinearCopositiveTemplate <: AbstractTemplate end

"""
    LinearCopositiveFunction(c)

A node function `V(x) = c'x` of a [`LinearCopositiveTemplate`](@ref).
"""
struct LinearCopositiveFunction{C <: AbstractVector}
    c::C
end

(V::LinearCopositiveFunction)(x::AbstractVector{<:Real}) = LinearAlgebra.dot(V.c, x)

function add_function_variables!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return JuMP.@variable(model, [1:dimension], base_name = "c_$(node)")
end

solution_value(::LinearCopositiveTemplate, c) = LinearCopositiveFunction(JuMP.value.(c))

homogeneity_degree(::LinearCopositiveTemplate) = 1

function add_normalization!(model::JuMP.Model, ::LinearCopositiveTemplate, c)
    JuMP.@constraint(model, c .>= 1)

    return nothing
end

function add_decrease!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    c_src,
    c_dst,
    map::AbstractMatrix;
    scale = 1,
)
    JuMP.@constraint(model, transpose(map) * c_dst .<= scale * c_src)

    return nothing
end

# On the orthant only: a positive system never leaves it.
is_applicable(::LinearCopositiveTemplate, system) = is_positive(system)

function decrease_slack(
    ::LinearCopositiveTemplate,
    V_src::LinearCopositiveFunction,
    V_dst::LinearCopositiveFunction,
    map::AbstractMatrix;
    scale = 1,
)
    return minimum(scale * V_src.c - transpose(map) * V_dst.c)
end

# Under composition, (Aᵀc)ᵀx stays positive when A ≥ 0 has no zero column;
# under the inverse, when A⁻¹ ≥ 0.
is_closed_under(::LinearCopositiveTemplate, ::Addition, system) = true

function is_closed_under(::LinearCopositiveTemplate, ::Composition, system)
    return all(A -> all(>=(0), A) && all(>(0), sum(A; dims = 1)), mode_matrices(system))
end

function is_closed_under(::LinearCopositiveTemplate, ::InverseComposition, system)
    is_invertible(system) || return false
    return all(A -> all(>=(0), inv(A)), mode_matrices(system))
end

has_dual(::LinearCopositiveTemplate) = true
dual(::LinearCopositiveTemplate) = DualCopositiveTemplate()
dual(::LinearCopositiveTemplate, V::LinearCopositiveFunction) = DualCopositiveFunction(V.c)
