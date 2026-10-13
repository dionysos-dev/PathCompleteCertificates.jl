import JuMP
import LinearAlgebra

"""
    ParallelFacesPolyhedralTemplate(G; min_weight = 1e-3)
    ParallelFacesPolyhedralTemplate(n_nodes, dimension; min_weight = 1e-3)

The polytopes with pairs of parallel faces of
[athanasopoulos2019polyhedral](@citet), eq. (10): at node ``s``,

```math
V_s(x) = \\max_k \\frac{|(G_s x)_k|}{w_{s,k}},
```

where `G` holds one fixed invertible matrix per node (the identity by default)
and the weights ``w_{s,k}``, at least `min_weight`, are the variables.
"""
struct ParallelFacesPolyhedralTemplate{T <: Real} <: AbstractTemplate
    G::Vector{Matrix{T}}
    min_weight::T

    function ParallelFacesPolyhedralTemplate(
        G::AbstractVector{<:AbstractMatrix{T}};
        min_weight::Real = 1e-3,
    ) where {T <: Real}
        isempty(G) && throw(ArgumentError("at least one node matrix is required"))
        min_weight > 0 || throw(ArgumentError("min_weight must be positive"))

        dimension = size(first(G), 1)

        for (node, G_node) in enumerate(G)
            size(G_node) == (dimension, dimension) || throw(
                ArgumentError(
                    "G[$node] has size $(size(G_node)); expected " *
                    "($dimension, $dimension)",
                ),
            )

            # The edge condition needs G_src^-1.
            LinearAlgebra.rank(G_node) == dimension ||
                throw(ArgumentError("G[$node] is singular; it must have full rank"))
        end

        weight = convert(T, min_weight)

        return new{T}(collect(Matrix{T}, G), weight)
    end
end

function ParallelFacesPolyhedralTemplate(
    n_nodes::Integer,
    dimension::Integer;
    min_weight::Real = 1e-3,
)
    n_nodes > 0 || throw(ArgumentError("n_nodes must be positive"))
    dimension > 0 || throw(ArgumentError("dimension must be positive"))

    identity = Matrix{Float64}(LinearAlgebra.I, dimension, dimension)

    return ParallelFacesPolyhedralTemplate(
        [copy(identity) for _ in 1:n_nodes];
        min_weight = min_weight,
    )
end

"""
    ParallelFacesPolyhedralFunction(G, w)

A node function `V(x) = max_k |(Gx)_k| / w_k` of a [`ParallelFacesPolyhedralTemplate`](@ref).
"""
struct ParallelFacesPolyhedralFunction{M <: AbstractMatrix, W <: AbstractVector}
    G::M
    w::W
end

(V::ParallelFacesPolyhedralFunction)(x::AbstractVector{<:Real}) =
    maximum(abs.(V.G * x) ./ V.w)

function add_function_variables!(
    model::JuMP.Model,
    template::ParallelFacesPolyhedralTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0

    node <= length(template.G) || throw(
        ArgumentError(
            "the template carries $(length(template.G)) node matrices but the " *
            "graph has at least $node nodes",
        ),
    )

    G = template.G[node]

    size(G, 1) == dimension || throw(
        ArgumentError(
            "G[$node] is $(size(G, 1))-dimensional but the system is " *
            "$dimension-dimensional",
        ),
    )

    w = JuMP.@variable(model, [1:dimension], base_name = "w_$(node)")

    return ParallelFacesPolyhedralFunction(G, w)
end

function add_nonnegativity!(
    model::JuMP.Model,
    template::ParallelFacesPolyhedralTemplate,
    V::ParallelFacesPolyhedralFunction,
)
    # The weights are a denominator, so they must be bounded away from zero.
    JuMP.@constraint(model, V.w .>= template.min_weight)
    return nothing
end

solution_value(::ParallelFacesPolyhedralTemplate, V::ParallelFacesPolyhedralFunction) =
    ParallelFacesPolyhedralFunction(V.G, JuMP.value.(V.w))

homogeneity_degree(::ParallelFacesPolyhedralTemplate) = 1

function add_normalization!(
    model::JuMP.Model,
    ::ParallelFacesPolyhedralTemplate,
    ::ParallelFacesPolyhedralFunction,
)
    # The lower bound min_weight from `add_nonnegativity!` already excludes V = 0.
    return nothing
end

function add_decrease!(
    model::JuMP.Model,
    ::ParallelFacesPolyhedralTemplate,
    V_src::ParallelFacesPolyhedralFunction,
    V_dst::ParallelFacesPolyhedralFunction,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    margin == 0 || throw(
        ArgumentError(
            "ParallelFacesPolyhedralTemplate cannot express a margin: the weights sit in a " *
            "denominator, so the margin term is not linear in them",
        ),
    )

    # The induced infinity-norm bound |G_dst map G_src^-1| w_src <= scale * w_dst;
    # w_dst carries the scale since w is a denominator.
    M = abs.(V_dst.G * map * inv(V_src.G))

    JuMP.@constraint(model, M * V_src.w .<= scale * V_dst.w)

    return nothing
end

function decrease_slack(
    ::ParallelFacesPolyhedralTemplate,
    V_src::ParallelFacesPolyhedralFunction,
    V_dst::ParallelFacesPolyhedralFunction,
    map::AbstractMatrix;
    scale = 1,
)
    M = abs.(V_dst.G * map * inv(V_src.G))

    return minimum(scale * V_dst.w - M * V_src.w)
end

# The max of two such norms with the same G is one, with the smaller weights.
is_closed_under(template::ParallelFacesPolyhedralTemplate, ::Maximum, system) =
    allequal(template.G)

reindex(template::ParallelFacesPolyhedralTemplate, origins::AbstractVector) =
    ParallelFacesPolyhedralTemplate(
        _reindexed_data(template.G, origins, "node matrices");
        min_weight = template.min_weight,
    )
