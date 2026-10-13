"""
    AbstractLift

The lift of an [`Operation`](@ref): a path-complete graph whose nodes are
combinations of the original nodes. When `lift(L, G)` simulates `H`,
`G ≤_V H` for every template closed under [`requirements`](@ref)`(L)`.
"""
abstract type AbstractLift end

"""
    Lifted(graph, origins)

The lifted `graph` and, for each of its nodes, the original nodes it stands
for.
"""
struct Lifted{G <: CertificateGraph, O}
    graph::G
    origins::Vector{O}
end

graph(lifted::Lifted) = lifted.graph
origins(lifted::Lifted) = lifted.origins

"""
    lift(L, graph) -> Lifted

The lifted graph of `graph`, which must have one mode per edge.
"""
function lift end

"""
    requirements(L) -> Tuple

The [`Operation`](@ref)s a template must be closed under for `L` to be valid
on it.
"""
requirements(::AbstractLift) = ()

"""
    simulation(L, G, H; optimizer = nothing)

The simulation of `H` by `lift(L, G)`, or `nothing` when there is none; it
proves `G ≤_V H` for every template closed under `requirements(L)`
[philippe2019complete; Thm. 3.5](@cite),
[debauche2024thesis; Thms. 7.18, 7.55, 7.56, 7.65 and 7.66](@cite).
`optimizer` is used by [`SumLift`](@ref)`()` only.
"""
function simulation(
    L::AbstractLift,
    G::CertificateGraph,
    H::CertificateGraph;
    optimizer = nothing,
)
    lifted = lift(L, G)
    map = simulation(graph(lifted), H)
    map === nothing && return nothing
    return origins(lifted)[map]
end

"""
    is_valid(L, template, system) -> Bool

Whether ``G ≤_V L(G)`` for every path-complete ``G``, for `template` on
`system`. True when the template is closed under `requirements(L)`, or its
dual under `requirements(dual(L))` on the dual system
[debauche2024thesis; Prop. 7.5](@cite).
"""
function is_valid(L::AbstractLift, template, system)
    all(op -> is_closed_under(template, op, system), requirements(L)) && return true

    has_dual(template) && !has_input(system) || return false

    dual_template = dual(template)
    dual_system = dual(system)

    return all(op -> is_closed_under(dual_template, op, dual_system), requirements(dual(L)))
end

const _LIFT_NODE_LIMIT = 1024

function _check_lift_size(g::CertificateGraph, what::AbstractString, lifted_nodes)
    _require_one_mode_per_edge(g, "the $what")

    lifted_nodes <= _LIFT_NODE_LIMIT || throw(
        ArgumentError(
            "the $what of a graph with $(n_nodes(g)) nodes has $lifted_nodes nodes, " *
            "more than the $_LIFT_NODE_LIMIT this builds; `simulation` decides the " *
            "ordering without building it",
        ),
    )

    return nothing
end
