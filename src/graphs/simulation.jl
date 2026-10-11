"""
    simulation(G, H) -> Union{Nothing, Vector{Int}}

A map `R` from the nodes of `H` to those of `G` with `(R(a), R(b), i)` an edge
of `G` for every edge `(a, b, i)` of `H` — Definition 3.1 of Philippe & Jungers
— or `nothing` when none exists. `G` then *simulates* `H`.

Simulation decides the ordering that holds for every template and every
system (their Theorem 3.5): `H` is no worse than `G` for all of them exactly
when `G` simulates `H`. Deciding it is a labelled graph homomorphism, NP-hard in
general; the search here is backtracking with the greatest
[`simulation_relation`](@ref) as its domain, which is also a necessary
condition. Letter graphs only.
"""
function simulation(G::_HS.GraphAutomaton, H::_HS.GraphAutomaton)
    relation = simulation_relation(G, H)
    relation === nothing && return nothing

    edges_H = [(source(e), dest(e), label(H, e)) for e in edges(H)]
    index = successors(G)
    assignment = zeros(Int, n_nodes(H))

    adjacent(a, b, letter) = b in get(index, (a, letter), Int[])

    function consistent(h)
        for (a, b, letter) in edges_H
            (a <= h && b <= h) || continue
            adjacent(assignment[a], assignment[b], letter) || return false
        end
        return true
    end

    function extend(h)
        h > n_nodes(H) && return true
        for candidate in relation[h]
            assignment[h] = candidate
            consistent(h) && extend(h + 1) && return true
        end
        assignment[h] = 0
        return false
    end

    return extend(1) ? assignment : nothing
end

"""
    simulation_relation(G, H) -> Union{Nothing, Vector{Vector{Int}}}

The greatest relation `ℛ` between the nodes of `H` and those of `G` such that
whenever `(h, a) ∈ ℛ` and `(h, h′, i)` is an edge of `H`, some edge `(a, b, i)`
of `G` has `(h′, b) ∈ ℛ` — as `relation[h]`, the nodes of `G` related to `h` —
or `nothing` when some node of `H` is related to none.

This is the simulation preorder of automata theory, a greatest fixed point
computed in polynomial time, and it is exactly the question "does the
[`MinLift`](@ref) of `G` simulate `H`": read `R(h) = relation[h]` and the
subset-lift edge condition is the relation's. It therefore decides the ordering
for every template closed under [`Minimum`](@ref) (Debauche, Thm. 8.1); on the
dual graphs, for every template closed under [`Maximum`](@ref) (Thm. 8.5). It
is also a necessary condition for [`simulation`](@ref), which searches inside it.
Letter graphs only.
"""
function simulation_relation(G::_HS.GraphAutomaton, H::_HS.GraphAutomaton)
    index = successors(G)
    edges_H = [(source(e), dest(e), label(H, e)) for e in edges(H)]

    relation = [Set(nodes(G)) for _ in nodes(H)]
    changed = true

    while changed
        changed = false

        for (h, h′, letter) in edges_H, a in collect(relation[h])
            matched = any(b in relation[h′] for b in get(index, (a, letter), Int[]))
            matched && continue

            delete!(relation[h], a)
            changed = true
        end
    end

    any(isempty, relation) && return nothing

    return [sort!(collect(related)) for related in relation]
end
