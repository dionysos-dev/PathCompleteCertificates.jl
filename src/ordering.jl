# Comparing two graphs for a template: is one guaranteed no worse than the
# other, whatever the system? Reads graphs, a template's closure declarations
# and, for the addition-closed case, a linear program -- so it belongs to no
# axis, like `aggregation.jl`. The subset lifts of `lifts/subsets.jl` are the
# exhibits of what is decided here; none is built.

import JuMP

"""
    OrderWitness(kind, data)

Evidence returned by [`order_witness`](@ref) that one graph is no worse than
another for a template: `kind` names the procedure — `:simulation` (a map
`H → G`), `:minimum` or `:maximum` (a relation), `:addition` (an integer
matrix) — and `data` is the object itself, checkable by hand.
"""
struct OrderWitness{D}
    kind::Symbol
    data::D
end

"""
    conic_witness(G, H; optimizer) -> Union{Nothing, Matrix{Int}}

A nonnegative integer matrix `C` through which `H` is no worse than `G` for
every template closed under addition: the node functions `U = C·V` built from
any certificate `V` on `G` are a certificate on `H` for the same system
(Philippe, Athanasopoulos, Angeli & Jungers, Def. IV.2 and Thm. IV.4). `nothing`
when there is none.

Decided by a linear program: `C ≥ 0` with every row summing to at least one,
and for every letter `i` a nonnegative `K_i` writing each `i`-edge of `H` as a
combination of `i`-edges of `G` with `S_H^i C ≥ K_i S_G^i` and
`D_H^i C ≤ K_i D_G^i`, `S` and `D` the source and destination incidences. The
LP is complete for this order (Debauche, Thm. 7.35): feasible exactly when some
[`SumLift`](@ref) of `G` simulates `H`. A rational solution is scaled to an
integer one (Lemma 7.32). Letter graphs only.
"""
function conic_witness(G::_HS.GraphAutomaton, H::_HS.GraphAutomaton; optimizer)
    letters = union(alphabet(G), alphabet(H))

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    C = JuMP.@variable(model, [1:n_nodes(H), 1:n_nodes(G)], lower_bound = 0)
    JuMP.@constraint(model, [h in 1:n_nodes(H)], sum(C[h, :]) >= 1)

    for letter in letters
        edges_G = [e for e in edges(G) if label(G, e) == letter]
        edges_H = [e for e in edges(H) if label(H, e) == letter]

        isempty(edges_H) && continue
        isempty(edges_G) && return nothing

        S_G, D_G = _incidences(G, edges_G)
        S_H, D_H = _incidences(H, edges_H)

        K = JuMP.@variable(model, [1:length(edges_H), 1:length(edges_G)], lower_bound = 0)
        JuMP.@constraint(model, S_H * C .>= K * S_G)
        JuMP.@constraint(model, D_H * C .<= K * D_G)
    end

    JuMP.optimize!(model)
    JuMP.termination_status(model) in _FEASIBLE_TERMINATION_STATUSES || return nothing

    return _integerise(JuMP.value.(C))
end

# Source and destination incidences of a list of edges: one row per edge, one
# column per node.
function _incidences(graph, edge_list)
    S = zeros(Int, length(edge_list), n_nodes(graph))
    D = zeros(Int, length(edge_list), n_nodes(graph))

    for (k, edge) in enumerate(edge_list)
        S[k, source(edge)] = 1
        D[k, dest(edge)] = 1
    end

    return S, D
end

# Any positive multiple of a solution is one, so scale to the least integer
# matrix: clip solver noise, rationalise, clear denominators, divide by the
# common factor.
function _integerise(C::AbstractMatrix{<:Real}; tol = 1e-8)
    clipped = map(c -> c < tol ? zero(c) : c, C)
    scaled = clipped ./ maximum(clipped)
    rationals = rationalize.(Int, scaled; tol = tol)
    denominators = lcm(denominator.(rationals)...)
    integers = Int.(rationals .* denominators)
    common = gcd(integers...)

    return common == 0 ? integers : integers .÷ common
end

"""
    order_witness(G, H; template, system, optimizer = nothing)

Evidence that `H` is no worse than `G` for `template` on any system —
``G ≤_V H`` in Debauche, Della Rossa & Jungers, Def. 4 — as an
[`OrderWitness`](@ref), or `nothing` when none of the procedures the template
is entitled to finds one.

Which procedures apply is read from the template's closures on `system`:
[`simulation`](@ref) always (the template-free order); the
[`simulation_relation`](@ref) under [`Minimum`](@ref), the same on the dual
graphs under [`Maximum`](@ref); [`conic_witness`](@ref) under
[`Addition`](@ref), for which an `optimizer` is needed. Each is complete for
its order, so `nothing` from all of them means that, for the closures declared,
no such guarantee holds. Letter graphs only.
"""
function order_witness(
    G::_HS.GraphAutomaton,
    H::_HS.GraphAutomaton;
    template::AbstractTemplate,
    system,
    optimizer = nothing,
)
    map = simulation(G, H)
    map === nothing || return OrderWitness(:simulation, map)

    if is_closed_under(template, Minimum(), system)
        relation = simulation_relation(G, H)
        relation === nothing || return OrderWitness(:minimum, relation)
    end

    if is_closed_under(template, Maximum(), system)
        relation = simulation_relation(dual(G), dual(H))
        relation === nothing || return OrderWitness(:maximum, relation)
    end

    if is_closed_under(template, Addition(), system)
        optimizer === nothing && throw(
            ArgumentError(
                "the template is closed under addition; deciding that order is a " *
                "linear program and needs an optimizer",
            ),
        )

        C = conic_witness(G, H; optimizer)
        C === nothing || return OrderWitness(:addition, C)
    end

    return nothing
end

"""
    is_no_worse(H, G; template, system, optimizer = nothing) -> Bool

Whether `H` is guaranteed no worse a graph than `G` for `template`, whatever
the system: [`order_witness`](@ref)`(G, H; ...) !== nothing`. Reads as the
literature's ``G ≤_V H``.
"""
is_no_worse(H::_HS.GraphAutomaton, G::_HS.GraphAutomaton; kwargs...) =
    order_witness(G, H; kwargs...) !== nothing

"""
    simplify(graph; template, system) -> graph

The one-node graph, when `graph` certifies nothing for `template` that a common
function would not; `graph` itself otherwise.

That is the case when the template is closed under [`Minimum`](@ref) and
`graph` has a complete induced subgraph, or closed under [`Maximum`](@ref) and
it has a co-complete one ([`closed_subgraph`](@ref)): the minimum, or maximum,
of the node functions over that subgraph is a common function. Corollary 7.53
of Debauche, complete graphs, is the special case where the subgraph is the
whole graph. The alphabet is the system's.
"""
function simplify(graph::_HS.GraphAutomaton; template::AbstractTemplate, system)
    letters = 1:length(mode_matrices(system))

    collapses =
        (
            is_closed_under(template, Minimum(), system) &&
            !isempty(closed_subgraph(graph, letters; direction = :out))
        ) || (
            is_closed_under(template, Maximum(), system) &&
            !isempty(closed_subgraph(graph, letters; direction = :in))
        )

    collapses || return graph

    return seed(_HS.OneStateAutomaton(length(letters)))
end
