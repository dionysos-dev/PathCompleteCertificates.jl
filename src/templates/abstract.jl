"""
    AbstractTemplate

A family of candidate node functions, passed as an instance such as
`QuadraticTemplate()`. Stability also accepts SetProg set families directly.
"""
abstract type AbstractTemplate end

"""
    homogeneity_degree(template) -> Int

The degree `p` such that `V(cx) = cᵖ V(x)` for every function of the template.
"""
function homogeneity_degree end

"""
    add_function_variables!(model, template, dimension, node)

Add the variables of the node function at `node`, with the constraints that
make it a member of the template, and return the function.
"""
function add_function_variables! end

"""
    add_normalization!(model, template, V)

Constrain `V` to be positive away from the origin, at a fixed scale, which
excludes the trivial function `V ≡ 0`.
"""
function add_normalization! end

"""
    add_decrease!(model, template, V_src, V_dst, map; scale = 1)

The decrease condition of an edge: `V_dst` after `map` is at most `scale`
times `V_src`. Constrain, for every ``x``,
``\\text{scale} \\cdot V_{src}(x) \\ge V_{dst}(\\text{map} \\cdot x)``.
"""
function add_decrease! end

"""
    solution_value(template, V)

The node function `V` after `optimize!`, with values in place of variables.
"""
function solution_value end

"""
    is_applicable(template, system) -> Bool

Whether `template` applies to the dynamics of `system`; `true` by default. A
problem refuses a template that does not, and no lift is valid for it.
"""
is_applicable(::AbstractTemplate, system) = true

# The node datum of `data` at `node`, or an error naming `what` when the
# template carries fewer than the graph has nodes.
function _node_datum(data::AbstractVector, node::Integer, what::AbstractString)
    node <= length(data) || throw(
        ArgumentError(
            "the template carries $(length(data)) $what but the graph has at least " *
            "$node nodes",
        ),
    )
    return data[node]
end

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
