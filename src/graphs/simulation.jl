"""
    simulation(G, H) -> Union{Nothing, Vector{Int}}

A map `R` from the nodes of `H` to those of `G` such that `(R(a), R(b), i)` is
an edge of `G` for every edge `(a, b, i)` of `H`, or `nothing` if none exists.
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

# The greatest simulation relation: relation[h] lists the nodes of G that can
# match h, or nothing when some h has none.
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
