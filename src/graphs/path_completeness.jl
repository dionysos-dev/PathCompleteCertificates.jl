# Path-completeness is PSPACE-complete; the subset construction is exponential
# in the number of nodes in the worst case.
"""
    is_path_complete(graph)
    is_path_complete(graph, alphabet)

Whether every switching sequence over `alphabet` labels a path of `graph`.
Without a second argument the alphabet is the modes `graph` uses; pass
`1:`[`n_modes`](@ref)`(system)` to ask about a system.
"""
is_path_complete(graph::CertificateGraph) = is_path_complete(graph, alphabet(graph))

is_path_complete(graph::WordGraph, alphabet::AbstractVector) =
    is_path_complete(expanded_form(graph), alphabet)

function is_path_complete(graph::_LetterGraph, alphabet::AbstractVector)
    # A path visits at least one node, so a graph with none reads no word, not
    # even the empty one.
    n_nodes(graph) == 0 && return false

    successors = _successors(graph)
    _covers_every_letter(graph, alphabet, successors) && return true
    is_co_complete(graph, alphabet) && return true

    # A word the graph cannot read leads the subset construction to the empty set.
    _, _, reads_every_word =
        _subset_construction(graph, alphabet, successors; stop_at_empty = true)

    return reads_every_word
end

"""
    is_complete(graph)
    is_complete(graph, alphabet)

Whether every node has an outgoing edge for every letter of `alphabet`;
sufficient, not necessary, for [`is_path_complete`](@ref). `false` on a graph
with a word of several modes.
"""
is_complete(graph::CertificateGraph) = is_complete(graph, alphabet(graph))

is_complete(graph::_LetterGraph, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _successors(graph))

is_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_complete(_as_letter_graph(graph), alphabet)

"""
    is_co_complete(graph)
    is_co_complete(graph, alphabet)

Whether every node has an incoming edge for every letter of `alphabet`;
sufficient, not necessary, for [`is_path_complete`](@ref). `false` on a graph
with a word of several modes.
"""
is_co_complete(graph::CertificateGraph) = is_co_complete(graph, alphabet(graph))

is_co_complete(graph::_LetterGraph, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _predecessors(graph))

is_co_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_co_complete(_as_letter_graph(graph), alphabet)

function _covers_every_letter(graph::_LetterGraph, alphabet, neighbours)
    for node in nodes(graph), letter in alphabet
        haskey(neighbours, (node, letter)) || return false
    end

    return true
end
