"""
    AbstractLift

A map from path-complete graphs to path-complete graphs whose nodes stand for
combinations of the original nodes under one [`Operation`](@ref): the lift of
an operation (Debauche, Della Rossa & Jungers, Defs. 5 and 7; Debauche,
Def. 8.15). It exists to compare graphs. When `lift(L, G)` simulates `H`,
`G ≤_V H` holds for every template closed under what the lift
[`requirements`](@ref): a certificate on `G`, combined along the simulation,
is one on `H`. [`compare`](@ref) runs every lift on a pair of graphs.

A lift is an instance. It implements [`lift`](@ref) and
[`requirements`](@ref); it inherits [`simulation`](@ref), which builds the
lifted graph and searches a map into it, and overrides it where something
cheaper decides the same question. [`is_valid`](@ref) is written once.
"""
abstract type AbstractLift end

"""
    Lifted(graph, origins)

What a lift returns: the lifted `graph` and, for each of its nodes, the
original nodes it stands for — a subset, a multiset, or a `(node, word)` pair.
"""
struct Lifted{G <: CertificateGraph, O}
    graph::G
    origins::Vector{O}
end

graph(lifted::Lifted) = lifted.graph
origins(lifted::Lifted) = lifted.origins

"""
    lift(L, graph) -> Lifted

The lifted graph. One mode per edge; every lift preserves path-completeness.
"""
function lift end

"""
    requirements(L) -> Tuple

The [`Operation`](@ref)s a template must be closed under for `L` to be valid
on it; `()` for the identity lift, which is valid for every template.
"""
requirements(::AbstractLift) = ()

"""
    simulation(L, G, H; optimizer = nothing)

The simulation of `H` by `lift(L, G)`, or `nothing` when there is none. It
proves `G ≤_V H` for every template closed under `requirements(L)` (Philippe &
Jungers, Thm. 3.5; Debauche, Thms. 7.18, 7.55, 7.56, 7.65 and 7.66), and it is
the recipe for a certificate on `H` from one on `G`.

The default builds the lifted graph and returns the [`simulation`](@ref) map
from the nodes of `H`, read through `origins`: subsets, multisets or
`(node, word)` pairs of `G`. [`IdentityLift`](@ref) returns the plain map,
[`MinLift`](@ref) the greatest simulation relation, [`MaxLift`](@ref) that
relation on the dual graphs and [`SumLift`](@ref)`()` the integer matrix of a
linear program, each without building anything. `optimizer` is read by the
linear program only.
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

Whether `L` is guaranteed not to make the bound worse for `template` on
`system` — Definition 6 of Debauche, Della Rossa & Jungers: whether
``G ≤_V L(G)`` for every path-complete ``G``.

Written once: the template is closed under every operation the lift requires
([`requirements`](@ref), [`is_closed_under`](@ref)), or — when the template
[`has_dual`](@ref) — the dual template is closed under what the dual lift
requires, on the transposed system. The two questions are the same one
(Debauche, Prop. 7.5), so a closure declared on either of a dual pair of
templates serves both. A few methods override it where the literature proves
validity without closure, and say which theorem.

`false` never means unsound. Every lift preserves path-completeness, so a
certificate on the lifted graph certifies the system regardless; it only
carries no guarantee of improvement.
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
