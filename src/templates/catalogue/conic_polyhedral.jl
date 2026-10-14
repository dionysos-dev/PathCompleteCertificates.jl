"""
    ConicPolyhedralTemplate(cones; min_scale = 1)

The general polyhedral template: at node ``s``,

```math
V_s(x) = \\max_i |p_{s,i}^\\top x|,
```

with the rows of ``P_s`` as variables. `cones[s]` partitions the state space
into cones, one per row of ``P_s``, each a matrix whose columns are its extreme
rays; row ``i`` is constrained to attain the maximum on cone ``i``. `min_scale`
is the lower bound on ``c_s`` in ``V_s(x) \\ge c_s \\|x\\|_\\infty``.
The program is homogeneous, so `min_scale` only fixes its scale; a much
smaller one lets the solver's absolute tolerance show in the rate.
"""
struct ConicPolyhedralTemplate{T <: Real} <: AbstractTemplate
    cones::Vector{Vector{Matrix{T}}}
    min_scale::T

    function ConicPolyhedralTemplate(
        cones::AbstractVector{<:AbstractVector{<:AbstractMatrix{T}}};
        min_scale::Real = 1,
    ) where {T <: Real}
        isempty(cones) && throw(ArgumentError("at least one node partition is required"))
        min_scale > 0 || throw(ArgumentError("min_scale must be positive"))

        for (node, node_cones) in enumerate(cones)
            isempty(node_cones) &&
                throw(ArgumentError("node $node must have at least one cone"))
        end

        dimension = size(first(first(cones)), 1)

        for (node, node_cones) in enumerate(cones)
            for (i, cone) in enumerate(node_cones)
                size(cone, 1) == dimension || throw(
                    ArgumentError(
                        "cone $i of node $node lives in R^$(size(cone, 1)); " *
                        "expected R^$dimension",
                    ),
                )

                size(cone, 2) >= 1 ||
                    throw(ArgumentError("cone $i of node $node has no extreme ray"))
            end
        end

        # Floating point, so that integer rays take the default bound.
        F = float(promote_type(T, typeof(min_scale)))

        return new{F}(
            [collect(Matrix{F}, node_cones) for node_cones in cones],
            convert(F, min_scale),
        )
    end
end

"""
    ConicPolyhedralFunction(cones, P, c)

A node function `V(x) = max_i |(P x)_i|` of a [`ConicPolyhedralTemplate`](@ref),
with `V(x) ≥ c ‖x‖_∞`.
"""
struct ConicPolyhedralFunction{C, M, S}
    cones::C
    P::M
    c::S
end

(V::ConicPolyhedralFunction)(x::AbstractVector{<:Real}) = maximum(abs.(V.P * x))

function add_function_variables!(
    model::JuMP.Model,
    template::ConicPolyhedralTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0

    cones = _node_datum(template.cones, node, "node partitions")

    size(first(cones), 1) == dimension || throw(
        ArgumentError(
            "the partition of node $node lives in R^$(size(first(cones), 1)) but " *
            "the system is $dimension-dimensional",
        ),
    )

    P = JuMP.@variable(model, [1:length(cones), 1:dimension], base_name = "P_$(node)")
    c = JuMP.@variable(model, base_name = "c_$(node)")

    # Row i attains the maximum on cone i, which makes V linear on each cone.
    for (i, cone) in enumerate(cones), ray in eachcol(cone)
        values = P * ray
        for k in eachindex(cones)
            k == i && continue
            JuMP.@constraint(model, values[i] + values[k] >= 0)
            JuMP.@constraint(model, values[i] - values[k] >= 0)
        end
    end

    return ConicPolyhedralFunction(cones, P, c)
end

solution_value(::ConicPolyhedralTemplate, V::ConicPolyhedralFunction) =
    ConicPolyhedralFunction(V.cones, JuMP.value.(V.P), JuMP.value(V.c))

"""
    planar_conic_partition(order)

A partition of the upper half-plane into `4 * 2^(order - 1)` cones, each a
`2 x 2` matrix whose columns are its extreme rays; enough since the functions
of [`ConicPolyhedralTemplate`](@ref) are symmetric.
"""
function planar_conic_partition(order::Integer)
    order >= 1 || throw(ArgumentError("The order must be positive."))

    rays = ([1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [-1.0, 1.0], [-1.0, 0.0])
    cones = [hcat(rays[i], rays[i + 1]) for i in 1:(length(rays) - 1)]

    for _ in 2:order
        refined = Matrix{Float64}[]

        for cone in cones
            first_ray = vec(cone[:, 1])
            second_ray = vec(cone[:, 2])
            middle = first_ray + second_ray

            push!(refined, hcat(first_ray, middle))
            push!(refined, hcat(middle, second_ray))
        end

        cones = refined
    end

    return cones
end

homogeneity_degree(::ConicPolyhedralTemplate) = 1

# V(x) ≥ c ‖x‖_∞ with c ≥ min_scale: on cone i, row i is at least c |x_j|.
function add_normalization!(
    model::JuMP.Model,
    template::ConicPolyhedralTemplate,
    V::ConicPolyhedralFunction,
)
    JuMP.@constraint(model, V.c >= template.min_scale)

    for (i, cone) in enumerate(V.cones), ray in eachcol(cone)
        value = (V.P * ray)[i]
        for coordinate in ray
            JuMP.@constraint(model, value + V.c * coordinate >= 0)
            JuMP.@constraint(model, value - V.c * coordinate >= 0)
        end
    end

    return nothing
end

function add_decrease!(
    model::JuMP.Model,
    ::ConicPolyhedralTemplate,
    V_src::ConicPolyhedralFunction,
    V_dst::ConicPolyhedralFunction,
    map::AbstractMatrix;
    scale = 1,
)
    # On cone i, V_src is row i, so the condition is linear; imposing it on the
    # extreme rays covers the cone by homogeneity and convexity.
    for (i, cone) in enumerate(V_src.cones), ray in eachcol(cone)
        source_value = (V_src.P * ray)[i]
        destination_values = V_dst.P * (map * ray)

        JuMP.@constraint(model, scale * source_value .+ destination_values .>= 0)
        JuMP.@constraint(model, scale * source_value .- destination_values .>= 0)
    end

    return nothing
end

function decrease_slack(
    ::ConicPolyhedralTemplate,
    V_src::ConicPolyhedralFunction,
    V_dst::ConicPolyhedralFunction,
    map::AbstractMatrix;
    scale = 1,
)
    worst = Inf

    for (i, cone) in enumerate(V_src.cones)
        for ray in eachcol(cone)
            source_value = (V_src.P * ray)[i]
            destination_values = V_dst.P * (map * ray)

            worst = min(worst, minimum(scale * source_value .- abs.(destination_values)))
        end
    end

    return worst
end

reindex(template::ConicPolyhedralTemplate, origins::AbstractVector) =
    ConicPolyhedralTemplate(
        _reindexed_data(template.cones, origins, "partitions");
        min_scale = template.min_scale,
    )
