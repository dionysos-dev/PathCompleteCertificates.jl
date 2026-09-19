import JuMP
import LinearAlgebra

"""
    AbstractTemplate

Abstract supertype for families of candidate functions.

A template is passed as an **instance**, not as a type. `QuadraticTemplate()`
and `LinearCopositiveTemplate()` are singletons carrying nothing, but a
template is not in general determined by its type: [`PolyhedralTemplate`](@ref)
carries one fixed matrix per node, and there is nowhere to put that on a
`::Type{T}` argument.
"""
abstract type AbstractTemplate end

raw"""
    LinearCopositiveTemplate()

The template ``V(x) = c^\top x`` on the nonnegative orthant.  It is applicable
to positive switched systems only: every mode matrix must map ``\mathbb{R}^n_+``
into itself.
"""
struct LinearCopositiveTemplate <: AbstractTemplate end

raw"""
    QuadraticTemplate()

The template ``V(x) = x^\top P x``, with ``P`` positive definite.
"""
struct QuadraticTemplate <: AbstractTemplate end

raw"""
    PolyhedralTemplate(G; min_weight = 1e-3)
    PolyhedralTemplate(n_nodes, dimension; min_weight = 1e-3)

The symmetric ``2n``-face polyhedral template of Athanasopoulos et al.: at node
``s``,

```math
V_s(x) = \max_k \frac{|(G_s x)_k|}{w_{s,k}},
```

a weighted infinity norm in the coordinates fixed by ``G_s``. Its sublevel set
``\{x : -\gamma w_s \le G_s x \le \gamma w_s\}`` is a symmetric polytope with
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

raw"""
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

"""
    rate_exponent(template) -> Int

The degree of homogeneity of the template's functions: `V(cx) = c^d V(x)`.

The edge condition is `V_dst(A x) <= gamma^d V_src(x)`, so this is what makes
the `gamma` a driver bisects on mean the same thing for every template — a
contraction rate, and hence a joint-spectral-radius bound. A quadratic form is
degree 2; a linear functional and a norm are degree 1.
"""
function rate_exponent end

rate_exponent(::LinearCopositiveTemplate) = 1
rate_exponent(::QuadraticTemplate) = 2
rate_exponent(::PolyhedralTemplate) = 1

"""
    add_function_variables!(model, template, dimension, node)

Add the decision variables representing one candidate function at `node` and
return it.  `node` selects the node's fixed template data, where the template
has any, and names the variables.
"""
function add_function_variables! end

"""
    add_nonnegativity!(model, template, V)

Constrain the candidate function `V` to be nonnegative.  Strict positivity is
added separately by the stability problem's normalization.

Dispatch is on the *template*, not on the type of `V`: two templates can
perfectly well represent their functions with the same container, and then
dispatching on the container silently applies the wrong constraint.
"""
function add_nonnegativity! end

function add_function_variables!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    dimension::Integer,
    node::Integer,
)
    @assert dimension > 0
    return JuMP.@variable(model, [1:dimension], base_name = "c_$(node)")
end

function add_nonnegativity!(
    model::JuMP.Model,
    ::LinearCopositiveTemplate,
    c::AbstractVector,
)
    JuMP.@constraint(model, c .>= 0)
    return nothing
end

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

"""
    solution_value(template, V)

The fitted node function after `optimize!`: the same object with numbers where
it held JuMP variables.

A driver cannot just broadcast `JuMP.value` over whatever
[`add_function_variables!`](@ref) returned, because a node function may carry
fixed data alongside its variables — a `PolyhedralFunction` keeps its `G`.
"""
function solution_value end

solution_value(::LinearCopositiveTemplate, c) = JuMP.value.(c)
solution_value(::QuadraticTemplate, P) = JuMP.value.(P)
solution_value(::PolyhedralTemplate, V::PolyhedralFunction) =
    PolyhedralFunction(V.G, JuMP.value.(V.w))
