const _SetFamily =
    Union{SetProg.AbstractVariable, AbstractVector{<:SetProg.AbstractVariable}}

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
    add_normalization!(model, template, V; conditioning_bound = Inf)

Constrain `V` to be positive away from the origin, at a fixed scale, which
excludes the trivial function `V ≡ 0`: its set contains, or lies in, a fixed
reference set. For an ellipsoid, a finite `conditioning_bound` also bounds its
matrix by `conditioning_bound * I`.
"""
function add_normalization! end

"""
    add_decrease!(model, template, V_src, V_dst, map; scale = 1)

The decrease condition of an edge: `V_dst` after `map` is at most `scale`
times `V_src`. Constrain, for every ``x``,
``\\text{scale} \\cdot V_{src}(x) \\ge V_{dst}(\\text{map} \\cdot x)``; for a
SetProg family, as a set inclusion.
"""
function add_decrease! end

"""
    solution_value(template, V)

The node function `V` after `optimize!`, with values in place of variables:
for a SetProg family, the fitted set.
"""
function solution_value end

"""
    is_applicable(template, system) -> Bool

Whether `template` applies to the dynamics of `system`; `true` by default. The
copositive templates apply to positive systems only. A problem refuses a
template that does not apply, and no lift is valid for it.
"""
function is_applicable end

"""
    decrease_slack(template, V_src, V_dst, map; scale = 1)

The slack of the decrease condition `scale · V_src(x) ≥ V_dst(map · x)` for
fitted node functions: nonnegative when it holds, zero exactly when it is
tight. It is in the units of the fitted functions, so compare slacks within
one certificate only. Not implemented for polynomial and piecewise-quadratic
families, whose slacks would need an optimization of their own.
"""
function decrease_slack end

"""
    is_closed_under(template, operation, system) -> Bool

Whether combining members of the template by `operation` gives a member;
`false` by default. `system` matters only for [`Composition`](@ref) and
[`InverseComposition`](@ref).
"""
function is_closed_under end

"""
    reindex(template, origins)

The template for a lifted graph whose nodes come from `origins`. A single
template is unchanged; a vector, one template per node, follows `origins`, and
throws if a node merges origins with different templates.
"""
function reindex end

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

Whether `dual(template)` and `dual(template, V)` are defined; `false` by
default. The quadratic template is its own dual, and the two copositive
templates are each other's.
"""
function has_dual end
