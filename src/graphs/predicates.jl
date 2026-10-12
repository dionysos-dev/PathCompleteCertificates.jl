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

function is_path_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector)
    # Cheap sufficient conditions first.
    (is_complete(graph, alphabet) || is_co_complete(graph, alphabet)) && return true

    # The observer drops empty subsets, so an unreadable word is a missing edge.
    observer, _ = observer_graph(graph, alphabet)

    return is_complete(observer, alphabet)
end

is_path_complete(graph::WordGraph, alphabet::AbstractVector) =
    is_path_complete(first(expanded_form(graph)), alphabet)

"""
    is_complete(graph)
    is_complete(graph, alphabet)

Whether every node has an outgoing edge for every letter of `alphabet`;
sufficient, not necessary, for [`is_path_complete`](@ref).
"""
is_complete(graph::CertificateGraph) = is_complete(graph, alphabet(graph))

is_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _successors(graph))

is_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_complete(_letter_graph(graph), alphabet)

"""
    is_co_complete(graph)
    is_co_complete(graph, alphabet)

Whether every node has an incoming edge for every letter of `alphabet`;
sufficient, not necessary, for [`is_path_complete`](@ref).
"""
is_co_complete(graph::CertificateGraph) = is_co_complete(graph, alphabet(graph))

is_co_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _predecessors(graph))

is_co_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_co_complete(_letter_graph(graph), alphabet)

function _covers_every_letter(graph::_HS.GraphAutomaton, alphabet, index)
    for node in nodes(graph), letter in alphabet
        haskey(index, (node, letter)) || return false
    end

    return true
end

function _check_path_complete(graph::CertificateGraph, language)
    is_path_complete(graph, language) || throw(
        ArgumentError(
            "the graph is not path-complete for the system's switching language, " *
            "so its edge inequalities would certify the property for part of it " *
            "only; the graph reads the modes $(sort(alphabet(graph)))",
        ),
    )

    return nothing
end
