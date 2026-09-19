import JuMP
import LinearAlgebra

"""
    PolyhedralTemplate(G; min_weight = 1e-3)
    PolyhedralTemplate(n_nodes, dimension; min_weight = 1e-3)

The symmetric ``2n``-face polyhedral template of Athanasopoulos et al.: at node
``s``,

```math
V_s(x) = \\max_k \\frac{|(G_s x)_k|}{w_{s,k}},
```

a weighted infinity norm in the coordinates fixed by ``G_s``. Its sublevel set
``\\{x : -\\gamma w_s \\le G_s x \\le \\gamma w_s\\}`` is a symmetric polytope with
``2n`` faces, hence the name.

`G` holds one invertible matrix per node and is **fixed data, not a decision
variable** — only the weights ``w_s > 0`` are solved for, which keeps the edge
condition a linear program. The second constructor defaults every ``G_s`` to
the identity, which is the plain weighted infinity norm.

`min_weight` is the strict-positivity floor on the weights. It cannot be `0`:
``w`` sits in a denominator, so a zero weight leaves ``V_s`` undefined rather
than merely degenerate.
"""
struct PolyhedralTemplate{T <: Real} <: AbstractTemplate
    G::Vector{Matrix{T}}
    min_weight::T

    function PolyhedralTemplate(
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

            # The edge condition needs G_src^-1, so a singular template is not
            # merely a bad choice -- it has no edge condition at all.
            LinearAlgebra.rank(G_node) == dimension ||
                throw(ArgumentError("G[$node] is singular; it must have full rank"))
        end

        weight = convert(T, min_weight)

        return new{T}(collect(Matrix{T}, G), weight)
    end
end

function PolyhedralTemplate(n_nodes::Integer, dimension::Integer; min_weight::Real = 1e-3)
    n_nodes > 0 || throw(ArgumentError("n_nodes must be positive"))
    dimension > 0 || throw(ArgumentError("dimension must be positive"))

    identity = Matrix{Float64}(LinearAlgebra.I, dimension, dimension)

    return PolyhedralTemplate([copy(identity) for _ in 1:n_nodes]; min_weight = min_weight)
end

"""
    PolyhedralFunction(G, w)

One fitted node function of a [`PolyhedralTemplate`](@ref), `V(x) = max_k |(Gx)_k| / w_k`.

It bundles the node's fixed `G` with its weights `w`, because the edge
condition on `(src, dst)` needs ``|G_{dst} A G_{src}^{-1}|`` and so cannot be
written from the decision variables alone. `w` holds JuMP variables while the
model is being built and numbers after the solve.
"""
struct PolyhedralFunction{M <: AbstractMatrix, W <: AbstractVector}
    G::M
    w::W
end

(V::PolyhedralFunction)(x::AbstractVector{<:Real}) = maximum(abs.(V.G * x) ./ V.w)

function add_function_variables!(
    model::JuMP.Model,
    template::PolyhedralTemplate,
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

    return PolyhedralFunction(G, w)
end

function add_nonnegativity!(
    model::JuMP.Model,
    template::PolyhedralTemplate,
    V::PolyhedralFunction,
)
    # Not `>= 0`: the weights are a denominator, so they must be bounded away
    # from zero for the function to be defined at all.
    JuMP.@constraint(model, V.w .>= template.min_weight)
    return nothing
end

solution_value(::PolyhedralTemplate, V::PolyhedralFunction) =
    PolyhedralFunction(V.G, JuMP.value.(V.w))

rate_exponent(::PolyhedralTemplate) = 1

function add_normalization!(model::JuMP.Model, ::PolyhedralTemplate, ::PolyhedralFunction)
    # `add_nonnegativity!` already floors the weights, which normalizes too:
    # the edge conditions are homogeneous in w.
    return nothing
end

function add_domination!(
    model::JuMP.Model,
    ::PolyhedralTemplate,
    V_src::PolyhedralFunction,
    V_dst::PolyhedralFunction,
    map::AbstractMatrix;
    scale = 1,
    margin = 0,
)
    margin == 0 || throw(
        ArgumentError(
            "PolyhedralTemplate cannot express a margin: the weights sit in a " *
            "denominator, so the margin term is not linear in them",
        ),
    )

    # Under z = W_src^-1 G_src x this is an infinity-norm induced norm bound,
    # which row by row is |G_dst map G_src^-1| w_src <= scale * w_dst -- linear
    # in w, which keeps this template an LP. The *destination* carries the
    # scale because w sits in a denominator.
    M = abs.(V_dst.G * map * inv(V_src.G))

    JuMP.@constraint(model, M * V_src.w .<= scale * V_dst.w)

    return nothing
end

node_value(
    ::PolyhedralTemplate,
    ::AbstractProblem,
    V::PolyhedralFunction,
    x::AbstractVector{<:Real},
) = V(x)
