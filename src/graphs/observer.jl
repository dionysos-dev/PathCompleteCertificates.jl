"""
    observer_graph(graph) -> (observer, states)
    observer_graph(graph, alphabet) -> (observer, states)

The observer graph of `graph`. Its nodes are nonempty subsets of the nodes of
`graph`, starting from the set of all of them, and there is an edge `(P, Q, σ)`
when `Q` is the set of successors by `σ` of the nodes in `P`. `states[k]` is
the subset that observer node `k` stands for.
"""
observer_graph(graph::_LetterGraph) = observer_graph(graph, alphabet(graph))

function observer_graph(graph::_LetterGraph, alphabet::AbstractVector)
    states, transitions, _ =
        _subset_construction(graph, alphabet, _successors(graph); stop_at_empty = false)

    observer = empty_graph(length(states))
    for (p, q, letter) in transitions
        add_edge!(observer, p, q, letter)
    end

    return observer, states
end

# The subsets of nodes where a path reading a word can end, from the set of all
# nodes, letter by letter, and the transitions between them; empty subsets are
# dropped. Also returns whether every word is read: no letter ever leads to the
# empty subset. With `stop_at_empty`, returns at the first that does. `index` is
# `_successors(graph)`, built by the caller.
function _subset_construction(
    graph::_LetterGraph,
    alphabet::AbstractVector,
    index;
    stop_at_empty::Bool,
)
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

# A subset as a dictionary key: its nodes, sorted, as a tuple.
_key(subset) = Tuple(sort!(collect(subset)))

# The common function [philippe2019path] is the minimum over these subsets of
# the maximum of the node functions within each: every node alone on a complete
# graph (Cor. III.3), all nodes together on a co-complete one, the observer
# states otherwise (Thm. III.8). A word graph has none: no state is constrained
# inside a word.
function _common_states(graph::CertificateGraph, alphabet::AbstractVector)
    letter_graph = _letter_graph(graph, "common")

    is_complete(letter_graph, alphabet) && return [[node] for node in nodes(letter_graph)]
    is_co_complete(letter_graph, alphabet) && return [collect(nodes(letter_graph))]

    return last(observer_graph(letter_graph, alphabet))
end
