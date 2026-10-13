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

function is_path_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector)
    (is_complete(graph, alphabet) || is_co_complete(graph, alphabet)) && return true

    successors = _successors(graph)

    # Read the words letter by letter. After a word `w`, track `S`, the nodes
    # where a path of the graph reading `w` can end. Before any letter, `S` is
    # all nodes; a mode `σ` sends `S` to its successors by `σ`. An empty `S` is
    # a word the graph cannot read. There are finitely many sets, so the search
    # ends.
    start = Set(nodes(graph))
    seen = Set{Tuple{Vararg{Int}}}([_key(start)])
    pending = [start]

    while !isempty(pending)
        subset = pop!(pending)

        for mode in alphabet
            reachable = _step(successors, subset, mode)

            isempty(reachable) && return false

            key = _key(reachable)
            if !(key in seen)
                push!(seen, key)
                push!(pending, reachable)
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
