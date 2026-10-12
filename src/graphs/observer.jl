"""
    observer_graph(graph) -> (observer, states)
    observer_graph(graph, alphabet) -> (observer, states)

The subset construction of `graph` from the set of all its nodes: a node of the
observer per nonempty subset reached, `states[k]` being the subset node `k`
stands for, and an edge `(P, Q, σ)` when `Q` is the set of nodes an edge
reading `σ` leads to from some node of `P`. Empty subsets are dropped, so the
observer is complete for `alphabet` exactly when `graph` is path-complete for
it, which is how [`is_path_complete`](@ref) decides. It is the graph on which
Theorem III.8 of Philippe, Athanasopoulos, Angeli & Jungers states the common
function of a graph that is neither complete nor co-complete, which is how
[`common`](@ref) reads it. `alphabet` defaults to the modes `graph` uses.
"""
observer_graph(graph::_HS.GraphAutomaton) = observer_graph(graph, sort(alphabet(graph)))

function observer_graph(graph::_HS.GraphAutomaton, alphabet::AbstractVector)
    index = _successors(graph)
    start = Set(nodes(graph))

    states = [start]
    ids = Dict{Tuple{Vararg{Int}}, Int}(_key(start) => 1)
    transitions = Tuple{Int, Int, Int}[]
    pending = [1]

    while !isempty(pending)
        p = popfirst!(pending)

        for letter in alphabet
            reachable = _step(index, states[p], letter)
            isempty(reachable) && continue

            q = get!(ids, _key(reachable)) do
                push!(states, reachable)
                push!(pending, length(states))
                return length(states)
            end

            push!(transitions, (p, q, letter))
        end
    end

    observer = empty_graph(length(states))
    for (p, q, letter) in transitions
        add_edge!(observer, p, q, letter)
    end

    return observer, states
end

# The nodes reachable from `subset` by one edge reading `letter`.
function _step(index, subset, letter::Integer)
    reachable = Set{Int}()

    for node in subset
        union!(reachable, get(index, (node, letter), Int[]))
    end

    return reachable
end

# A subset as an immutable key. The key type is written out where the
# dictionary is made: inferred from the first subset, it would pin the arity.
_key(subset) = Tuple(sort!(collect(subset)))
