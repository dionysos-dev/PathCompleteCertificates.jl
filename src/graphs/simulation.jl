# Simulation between labelled graphs, in the two forms the ordering theory
# uses: as a map (Philippe & Jungers, Def. 3.1), which decides the
# template-free order, and as a relation, which decides the min-closed order
# without building the min lift. Pure graph work; the orders themselves are in
# `ordering.jl`.

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

"""
    closed_subgraph(graph, alphabet; direction = :out) -> Vector{Int}

The largest set of nodes every one of which has, for every letter of
`alphabet`, an edge reading it into the set — an *outgoing* edge with
`direction = :out`, the largest **complete** induced subgraph; an *incoming* one
with `:in`, the largest **co-complete** induced subgraph. Empty when there is
none.

A greatest fixed point: delete nodes lacking such an edge until none does.

Why it matters: for a template closed under [`Minimum`](@ref), the minimum of
the node functions over a complete induced subgraph is a common function
(Corollary III.3 of Philippe et al. on the induced subgraph), so the graph
certifies nothing a one-node graph would not. Dually for [`Maximum`](@ref) and
co-complete. [`simplify`](@ref) reads it.
"""
function closed_subgraph(graph::_HS.GraphAutomaton, alphabet; direction::Symbol = :out)
    direction in (:out, :in) || throw(ArgumentError("direction must be :out or :in"))

    index = direction == :out ? successors(graph) : predecessors(graph)
    members = Set(nodes(graph))
    changed = true

    while changed
        changed = false

        for node in collect(members), letter in alphabet
            any(other in members for other in get(index, (node, letter), Int[])) && continue

            delete!(members, node)
            changed = true
            break
        end
    end

    return sort!(collect(members))
end
