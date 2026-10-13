"""
    observer_graph(graph) -> (observer, states)
    observer_graph(graph, alphabet) -> (observer, states)

The observer graph of `graph`. Its nodes are nonempty subsets of the nodes of
`graph`, starting from the set of all of them, and there is an edge `(P, Q, σ)`
when `Q` is the set of successors by `σ` of the nodes in `P`. `states[k]` is
the subset that observer node `k` stands for.
"""
observer_graph(graph::_HS.GraphAutomaton) = observer_graph(graph, sort(alphabet(graph)))

function observer_graph(graph::_HS.GraphAutomaton, alphabet::AbstractVector)
    states, transitions, _ = _subset_construction(graph, alphabet; stop_at_empty = false)

    observer = empty_graph(length(states))
    for (p, q, letter) in transitions
        add_edge!(observer, p, q, letter)
    end

    return observer, states
end

# The subsets of nodes where a path reading a word can end, from the set of all
# nodes, letter by letter, and the transitions between them; empty subsets are
# dropped. Also returns whether every word is read: no letter ever leads to the
# empty subset. With `stop_at_empty`, returns at the first that does.
function _subset_construction(
    graph::_HS.GraphAutomaton,
    alphabet::AbstractVector;
    stop_at_empty::Bool,
)
    index = _successors(graph)
    start = Set(nodes(graph))

    states = [start]
    ids = Dict{Tuple{Vararg{Int}}, Int}(_key(start) => 1)
    transitions = Tuple{Int, Int, Int}[]
    pending = [1]
    reads_every_word = true

    while !isempty(pending)
        p = popfirst!(pending)

        for letter in alphabet
            reachable = _step(index, states[p], letter)

            if isempty(reachable)
                reads_every_word = false
                stop_at_empty && return states, transitions, false
                continue
            end

            q = get!(ids, _key(reachable)) do
                push!(states, reachable)
                push!(pending, length(states))
                return length(states)
            end

            push!(transitions, (p, q, letter))
        end
    end

    return states, transitions, reads_every_word
end

# The nodes reachable from `subset` by one edge reading `letter`.
function _step(index, subset, letter::Integer)
    reachable = Set{Int}()

    for node in subset
        union!(reachable, get(index, (node, letter), Int[]))
    end

    return reachable
end

# The key type is written out where the dictionary is made, so the arity is free.
_key(subset) = Tuple(sort!(collect(subset)))

# The common function as a graph construction [philippe2017path]: from the values
# of the node functions at one point, their minimum on a complete graph
# (Cor. III.3), their maximum on a co-complete one, and otherwise the minimum
# over the observer states of the maximum within each (Thm. III.8). A word graph
# has none: no state is constrained inside a word.
function _common(graph::CertificateGraph, alphabet::AbstractVector, values::AbstractVector)
    letter_graph = _letter_graph(graph, "common")

    is_complete(letter_graph, alphabet) && return minimum(values)
    is_co_complete(letter_graph, alphabet) && return maximum(values)

    _, states = observer_graph(letter_graph, alphabet)

    return minimum(maximum(values[node] for node in state) for state in states)
end
