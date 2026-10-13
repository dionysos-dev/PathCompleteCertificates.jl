"""
    AbstractLift

An operation on graphs: `lift(L, G)` is path-complete when `G` is, and no
worse than `G` for every template closed under [`requirements`](@ref)`(L)`,
since a certificate on `G` gives one on `L(G)`. Lifts are the steps of
[`refine`](@ref), and decide the order between two graphs in
[`compare`](@ref): when `L(G)` simulates `H`, `G ≤_V H` for the same
templates.
"""
abstract type AbstractLift end

"""
    Lifted(graph, origins)

The lifted `graph` and, for each of its nodes, what it stands for in the
original: one node for a copy, a set of nodes for the min and max lifts, a
multiset for the sum lift, a `(node, word)` pair for the composition lifts.
"""
struct Lifted{G <: CertificateGraph, O}
    graph::G
    origins::Vector{O}
end

graph(lifted::Lifted) = lifted.graph

"""
    origins(lifted)

What each node of a [`Lifted`](@ref) graph stands for in the original graph.
"""
origins(lifted::Lifted) = lifted.origins

"""
    lift(L, graph) -> Lifted
    lift(L, graph, edges) -> Lifted
    lift(L, graph, node) -> Lifted

Apply `L` to the whole graph, at each of the given edges, or at a node. A lift
applied at edges is applied at every edge when none are given; the splits are
also applied at a node. A lift without the form asked for throws a
`MethodError`.
"""
function lift end

lift(L::AbstractLift, g::CertificateGraph) = lift(L, g, collect(edges(g)))

lift(L::AbstractLift, g::CertificateGraph, edge::_HS.GraphTransition) = lift(L, g, [edge])

"""
    requirements(L) -> Tuple

The [`Operation`](@ref)s a template must be closed under for `L` to be valid
on it; none for a lift that copies node functions or chains edge
inequalities.
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

function _check_edge_list(
    g::CertificateGraph,
    edge_list::AbstractVector{<:_HS.GraphTransition},
)
    isempty(edge_list) && throw(ArgumentError("the edge list is empty"))
    allunique(edge_list) || throw(ArgumentError("the edge list repeats an edge"))
    all(edge -> has_edge(g, edge), edge_list) ||
        throw(ArgumentError("the edge list contains an edge that is not in the graph"))
    return nothing
end
