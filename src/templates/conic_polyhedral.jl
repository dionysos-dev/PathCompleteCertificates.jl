import JuMP

"""
    ConicPolyhedralTemplate(cones; min_scale = 1e-3)

The general polyhedral template: at node ``s``,

```math
V_s(x) = \\max_i |p_{s,i}^\\top x|,
```

whose sublevel sets are polytopes whose **facets are themselves solved for**,
rather than fixed as in [`PolyhedralTemplate`](@ref). Less conservative, and
correspondingly larger.

`max` is not linear, so the program cannot be written without knowing which row
attains it. `cones[s]` supplies that: a partition of the state space into
cones, one per row of ``P_s``, each given as a matrix whose **columns are its
extreme rays**. Row ``i`` is then constrained to dominate on cone ``i``, and
every condition is imposed on the extreme rays — which is enough, because all
of them are positively homogeneous.

The construction is dimension-general; only [`planar_conic_partition`](@ref),
the ready-made partition, is two-dimensional.

`min_scale` is the floor on the auxiliary scale ``c_s`` in
``V_s(x) \\ge c_s \\|x\\|_\\infty``, which is what rules out ``V_s \\equiv 0``.
"""
struct ConicPolyhedralTemplate{T <: Real} <: AbstractTemplate
    cones::Vector{Vector{Matrix{T}}}
    min_scale::T

    function ConicPolyhedralTemplate(
        cones::AbstractVector{<:AbstractVector{<:AbstractMatrix{T}}};
        min_scale::Real = 1e-3,
    ) where {T <: Real}
        isempty(cones) && throw(ArgumentError("at least one node partition is required"))
        min_scale > 0 || throw(ArgumentError("min_scale must be positive"))

        # Every node's partition must be non-empty before any of them can be
        # asked for its dimension.
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

        return new{T}(
            [collect(Matrix{T}, node_cones) for node_cones in cones],
            convert(T, min_scale),
        )
    end
end

"""
    ConicPolyhedralFunction(cones, P, scale)

One fitted node function of a [`ConicPolyhedralTemplate`](@ref),
`V(x) = max_i |(P x)_i|`.

It carries the node's `cones` because the edge condition is imposed on their
extreme rays, and `scale` because the positivity condition is stated against
it. As with [`PolyhedralFunction`](@ref), the fixed data travels with the
variables — the decision variables alone do not determine the constraints.
"""
struct ConicPolyhedralFunction{C, M, S}
    cones::C
    P::M
    scale::S
end

(V::ConicPolyhedralFunction)(x::AbstractVector{<:Real}) = maximum(abs.(V.P * x))

function add_function_variables!(
    model::JuMP.Model,
    template::ConicPolyhedralTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0

    node <= length(template.cones) || throw(
        ArgumentError(
            "the template carries $(length(template.cones)) node partitions but " *
            "the graph has at least $node nodes",
        ),
    )

    cones = template.cones[node]

    size(first(cones), 1) == dimension || throw(
        ArgumentError(
            "the partition of node $node lives in R^$(size(first(cones), 1)) but " *
            "the system is $dimension-dimensional",
        ),
    )

    # One facet row per cone: row i is the one that attains the maximum there.
    P = JuMP.@variable(model, [1:length(cones), 1:dimension], base_name = "P_$(node)")

    scale =
        JuMP.@variable(model, base_name = "c_$(node)", lower_bound = template.min_scale,)

    return ConicPolyhedralFunction(cones, P, scale)
end

function add_nonnegativity!(
    model::JuMP.Model,
    ::ConicPolyhedralTemplate,
    V::ConicPolyhedralFunction,
)
    dimension = size(V.P, 2)

    for (i, cone) in enumerate(V.cones)
        for ray in eachcol(cone)
            values = V.P * ray

            # Positive definiteness with a margin: on its own cone the active
            # row is at least `scale * ||x||_inf`, written coordinatewise so it
            # stays linear.
            for j in 1:dimension
                JuMP.@constraint(model, values[i] + V.scale * ray[j] >= 0)
                JuMP.@constraint(model, values[i] - V.scale * ray[j] >= 0)
            end

            # Row i really is the maximum on cone i. Without this the program
            # would constrain a function that is not the template's `max`.
            for k in eachindex(V.cones)
                k == i && continue
                JuMP.@constraint(model, values[i] + values[k] >= 0)
                JuMP.@constraint(model, values[i] - values[k] >= 0)
            end
        end
    end

    return nothing
end

solution_value(::ConicPolyhedralTemplate, V::ConicPolyhedralFunction) =
    ConicPolyhedralFunction(V.cones, JuMP.value.(V.P), JuMP.value(V.scale))

# The partition is data for this template, not a graph construction: it
# partitions the state space, is indexed by node only because each node
# gets one, and nothing graph-shaped ever touches it.

"""
    planar_conic_partition(order)

A partition of the plane into `4 * 2^(order - 1)` cones, each returned as a
`2 x 2` matrix whose columns are its two extreme rays.

Only the upper half-plane is covered, from `(1, 0)` round to `(-1, 0)`: the
functions of [`ConicPolyhedralTemplate`](@ref) are symmetric, so the lower half
is determined. `order = 1` is the four base cones, and each further order
bisects every cone.

Two-dimensional, unlike the template it feeds — a partition in higher dimension
has to be supplied by the caller.
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

rate_exponent(::ConicPolyhedralTemplate) = 1

function _add_normalization!(
    model::JuMP.Model,
    ::ConicPolyhedralTemplate,
    ::ConicPolyhedralFunction,
)
    # The scale variable's own lower bound is the normalization: it forces
    # V >= min_scale * ||x||_inf, so V = 0 is excluded before this hook runs.
    return nothing
end

function add_domination!(
    model::JuMP.Model,
    ::ConicPolyhedralTemplate,
    V_src::ConicPolyhedralFunction,
    V_dst::ConicPolyhedralFunction,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    # On cone i of the source, V_src is the single row i, so the condition is
    # |row_r of P_dst . map x| <= scale * row_i of P_src . x for every row r --
    # linear. Imposing it on the extreme rays covers the cone, since both sides
    # are positively homogeneous and the constraint set is convex. On a ray the
    # margin term is a constant, so it stays linear too.
    for (i, cone) in enumerate(V_src.cones)
        for ray in eachcol(cone)
            source_value = (V_src.P * ray)[i]
            destination_values = V_dst.P * (map * ray)
            slack = margin * maximum(abs, ray)

            JuMP.@constraint(model, scale * source_value .+ destination_values .>= slack)
            JuMP.@constraint(model, scale * source_value .- destination_values .>= slack)
        end
    end

    return nothing
end

_node_value(
    ::ConicPolyhedralTemplate,
    ::AbstractProblem,
    V::ConicPolyhedralFunction,
    x::AbstractVector{<:Real},
) = V(x)
