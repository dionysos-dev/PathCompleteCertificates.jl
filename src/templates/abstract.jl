import JuMP
import LinearAlgebra

"""
    AbstractTemplate

A family of candidate node functions, passed as an instance such as
`QuadraticTemplate()`.
"""
abstract type AbstractTemplate end

"""
    homogeneity_degree(template) -> Int

The degree `p` such that `V(cx) = cᵖ V(x)` for every function of the template.
"""
function homogeneity_degree end

"""
    add_function_variables!(model, template, dimension, node)

Add the variables of the node function at `node` and return the function.
"""
function add_function_variables! end

"""
    add_nonnegativity!(model, template, V)

Constrain `V` to be nonnegative.
"""
function add_nonnegativity! end

"""
    add_normalization!(model, template, V)

Constrain `V` to exclude the trivial function `V ≡ 0`.
"""
function add_normalization! end

"""
    add_decrease!(model, template, V_src, V_dst, map; scale = 1, margin = 0)

The decrease condition of an edge: `V_dst` after `map` is at most `scale`
times `V_src`. Constrain, for every ``x``,

```math
\\text{scale} \\cdot V_{src}(x) - V_{dst}(\\text{map} \\cdot x)
    - \\text{margin}\\,\\|x\\|^p \\ge 0,
```

where ``p`` is [`homogeneity_degree`](@ref). A template that cannot express
`margin` throws unless `margin = 0`.
"""
function add_decrease! end

"""
    solution_value(template, V)

The node function `V` after `optimize!`, with values in place of variables.
"""
function solution_value end

"""
    check_dynamics(template, A)

Throw if `template` does not apply to the mode matrices `A`.
"""
function check_dynamics end

check_dynamics(::AbstractTemplate, ::AbstractVector{<:AbstractMatrix}) = nothing

"""
    decrease_slack(template, V_src, V_dst, map; scale = 1)

The slack of the decrease condition `scale · V_src(x) ≥ V_dst(map · x)` for
fitted node functions: nonnegative when it holds, zero exactly when it is
tight. It is in the units of the fitted functions, so compare slacks within
one certificate only.
"""
function decrease_slack end

"""
    is_closed_under(template, operation, system) -> Bool

Whether combining members of the template by `operation` gives a member;
`false` by default. `system` matters only for [`Composition`](@ref) and
[`InverseComposition`](@ref).
"""
is_closed_under(::AbstractTemplate, ::Operation, system) = false

"""
    reindex(template, origins)

The template for a lifted graph whose nodes come from `origins`.
Throws if a node merges origins with different per-node data.
"""
reindex(template::AbstractTemplate, ::AbstractVector) = template

# The original nodes of an origin: a node, a subset, or a (node, word) pair.
_origin_nodes(origin::Integer) = (origin,)
_origin_nodes(origin::AbstractVector{<:Integer}) = origin
_origin_nodes(origin::Tuple{<:Integer, <:Any}) = (first(origin),)

# One datum per new node, when its origins agree on it.
function _reindexed_data(
    data::AbstractVector,
    origins::AbstractVector,
    what::AbstractString,
)
    return map(origins) do origin
        members = _origin_nodes(origin)
        value = data[first(members)]

        all(member -> data[member] == value, members) || throw(
            ArgumentError(
                "the lift merges nodes $(collect(members)) whose $what differ; the " *
                "template carries one per node and cannot follow it",
            ),
        )

        return value
    end
end

"""
    has_dual(template) -> Bool

Whether `dual(template)` and `dual(template, V)` are defined; `false` by default.
"""
has_dual(::AbstractTemplate) = false

dual(template::AbstractTemplate) =
    throw(ArgumentError("no dual template is defined for $(nameof(typeof(template)))"))

"""
    dual(template, V)

The dual norm of a fitted node function `V`, as a member of `dual(template)`.
"""
dual(template::AbstractTemplate, V) =
    throw(ArgumentError("no dual node function is defined for $(nameof(typeof(template)))"))
