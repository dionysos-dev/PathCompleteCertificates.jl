# Path-completeness is PSPACE-complete; the subset construction is exponential
# in the number of nodes in the worst case.
"""
    is_path_complete(graph)
    is_path_complete(graph, alphabet)
    is_path_complete(graph, automaton)

Whether every switching sequence of the language (an alphabet, or a constraint
automaton) labels a path of `graph`. Without a second argument the alphabet is
the modes `graph` uses; pass [`language`](@ref)`(system)` to ask about a system.
"""
is_path_complete(graph::CertificateGraph) = is_path_complete(graph, alphabet(graph))

# Arbitrary switching is the constraint automaton with one node and a loop per mode.
function is_path_complete(graph::CertificateGraph, alphabet::AbstractVector)
    constraint = empty_graph(1)

    for mode in alphabet
        add_edge!(constraint, 1, 1, mode)
    end

    return is_path_complete(graph, constraint)
end

is_path_complete(graph::CertificateGraph, automaton::_HS.OneStateAutomaton) =
    is_path_complete(graph, 1:_HS.ntransitions(automaton))

is_path_complete(graph::WordGraph, constraint::_HS.GraphAutomaton) =
    is_path_complete(expanded_form(graph), constraint)

function is_path_complete(graph::_HS.GraphAutomaton, constraint::_HS.GraphAutomaton)
    modes = alphabet(constraint)

    # A graph reading every word reads any language over the same modes.
    (is_complete(graph, modes) || is_co_complete(graph, modes)) && return true

    successors = _successors(graph)

    # Read the admissible words letter by letter. After a word `w`, track a pair
    # `(q, S)`: `q` is the constraint node reached by reading `w`, which says what
    # may come next, and `S` the graph nodes where a path of the graph reading `w`
    # can end. Before any letter, `S` is all nodes; a transition `q --σ--> q′`
    # sends `S` to its successors by `σ`. An empty `S` is an admissible word the
    # graph cannot read. There are finitely many pairs, so the search ends.
    seen = Set{Tuple{Int, Tuple{Vararg{Int}}}}()
    pending = Tuple{Int, Set{Int}}[]

    for q in nodes(constraint)
        start = Set(nodes(graph))
        push!(seen, (q, _key(start)))
        push!(pending, (q, start))
    end

    while !isempty(pending)
        q, subset = pop!(pending)

        for transition in outgoing_edges(constraint, q)
            reachable = _step(successors, subset, label(constraint, transition))

            isempty(reachable) && return false

            key = (dest(transition), _key(reachable))
            if !(key in seen)
                push!(seen, key)
                push!(pending, (dest(transition), reachable))
            end
        end
    end

    return true
end

"""
    is_complete(graph)
    is_complete(graph, alphabet)

Whether every node has an outgoing edge for every letter of `alphabet`;
sufficient, not necessary, for [`is_path_complete`](@ref). `false` on a graph
with a word of several modes.
"""
is_complete(graph::CertificateGraph) = is_complete(graph, alphabet(graph))

is_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _successors(graph))

is_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_complete(_letter_graph(graph, "is_complete"), alphabet)

"""
    is_co_complete(graph)
    is_co_complete(graph, alphabet)

Whether every node has an incoming edge for every letter of `alphabet`;
sufficient, not necessary, for [`is_path_complete`](@ref). `false` on a graph
with a word of several modes.
"""
is_co_complete(graph::CertificateGraph) = is_co_complete(graph, alphabet(graph))

is_co_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _predecessors(graph))

is_co_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_co_complete(_letter_graph(graph, "is_co_complete"), alphabet)

function _covers_every_letter(graph::_HS.GraphAutomaton, alphabet, neighbours)
    for node in nodes(graph), letter in alphabet
        haskey(neighbours, (node, letter)) || return false
    end

    return true
end
