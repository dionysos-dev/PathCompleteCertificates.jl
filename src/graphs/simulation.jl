"""
    simulation(G, H) -> Union{Nothing, Vector{Int}}

A map `R` from the nodes of `H` to those of `G` with `(R(a), R(b), i)` an edge
of `G` for every edge `(a, b, i)` of `H` — Definition 3.1 of Philippe & Jungers
— or `nothing` when none exists. `G` then *simulates* `H`.

Simulation decides the ordering that holds for every template and every
system (their Theorem 3.5): `H` is no worse than `G` for all of them exactly
when `G` simulates `H`. Deciding it is a labelled graph homomorphism, NP-hard in
general; the search here is backtracking inside the greatest simulation
relation between the nodes, the one [`MinLift`](@ref) decides with, which is a
necessary condition. One mode per edge.
"""
function simulation(G::_HS.GraphAutomaton, H::_HS.GraphAutomaton)
    relation = _simulation_relation(G, H)
    relation === nothing && return nothing

    edges_H = [(source(e), dest(e), label(H, e)) for e in edges(H)]
    index = _successors(G)
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

# The greatest relation between the nodes of H and those of G in which every
# move of H is matched by a move of G, as relation[h], the nodes of G related
# to h, or nothing when some node of H is related to none. A greatest fixed
# point, polynomial, and read as a map into subsets it is the simulation of H
# by the min lift of G (Debauche, Thm. 8.1).
function _simulation_relation(G::_HS.GraphAutomaton, H::_HS.GraphAutomaton)
    index = _successors(G)
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
