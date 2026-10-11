# Path-completeness (Definition II.1 of Philippe, Athanasopoulos, Angeli &
# Jungers) and the two structural conditions that are sufficient for it
# (Definition III.2). Keep the distinction: III.2 is not II.1.

# Deciding path-completeness is NFA universality: PSPACE-complete, and the
# subset construction below is exponential in |V| in the worst case. It is
# usable because the graphs built here are not worst cases -- a De Bruijn graph
# visits about 2|V| subsets -- and because the short-circuits take the common
# cases out of the search. Refinement tests many candidate graphs with this
# predicate, so measure here first if a loop gets slow.
"""
    is_path_complete(graph)
    is_path_complete(graph, alphabet)
    is_path_complete(graph, automaton)

Whether every switching sequence of the language is readable in `graph` —
Definition II.1 of Philippe, Athanasopoulos, Angeli & Jungers: for any ``k ≥ 1``
and any ``σ_1 … σ_k`` over the alphabet there is a path
``(s_i, s_{i+1}, σ_i)_{i=1..k}`` in the graph.

**This is the soundness condition.** Without it the edge inequalities certify
nothing, whatever the solver reports.

It is *not* graph-theoretic completeness, where every pair of vertices is
adjacent, and it is strictly weaker than [`is_complete`](@ref) — see that
docstring.

Decided by the subset construction: a word is readable from some node exactly
when the set of nodes reachable by it is nonempty, so the graph is
path-complete iff the subset construction started from *all* nodes never
reaches the empty set. That is a finite search, since there are finitely many
subsets.

The second argument says which switching sequences must be readable. Under
arbitrary switching it is the alphabet, and every sequence of modes over it
must be; under constrained switching it is the system's automaton, and every
path of the automaton must be, which the same construction decides in product
with it. Pass [`language`](@ref) of the system whenever the question is about a
certificate: without a second argument the alphabet is the modes `graph`
happens to use, so a graph that never mentions a mode passes for its own labels
and is **not** path-complete for a system that has that mode.

A [`WordGraph`](@ref) is path-complete when its [`expanded_form`](@ref) is:
every word of the language is then a *factor* of the label of some path.
"""
is_path_complete(graph::CertificateGraph) = is_path_complete(graph, alphabet(graph))

function is_path_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector)
    # Definition III.2 implies II.1, and both are cheap and indexed, so try
    # them before paying for the subset construction.
    (is_complete(graph, alphabet) || is_co_complete(graph, alphabet)) && return true

    # The observer drops empty subsets, so a word some reachable subset cannot
    # read is a missing edge of it.
    observer, _ = observer_graph(graph, alphabet)

    return is_complete(observer, alphabet)
end

is_path_complete(graph::WordGraph, alphabet::AbstractVector) =
    is_path_complete(first(expanded_form(graph)), alphabet)

"""
    is_complete(graph)
    is_complete(graph, alphabet)

Whether every node has an *outgoing* edge for every letter of `alphabet` —
Definition III.2 of Philippe et al.

This is **sufficient but not necessary** for [`is_path_complete`](@ref): a
graph can read every word without every node reading every letter. Use this
one only when the stronger structure is what is needed — it is what licenses
the plain minimum of Corollary III.3, which is why
[`common`](@ref) dispatches on it.

A statement about letters, so a [`WordGraph`](@ref) with a longer word is never
complete.
"""
is_complete(graph::CertificateGraph) = is_complete(graph, alphabet(graph))

is_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _successors(graph))

is_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_complete(_letter_graph(graph), alphabet)

"""
    is_co_complete(graph)
    is_co_complete(graph, alphabet)

The dual of [`is_complete`](@ref): every node has an *incoming* edge for every
letter of `alphabet`. Also sufficient but not necessary for path-completeness,
and it licenses the maximum of Corollary III.3. The dual De Bruijn
graph is co-complete.
"""
is_co_complete(graph::CertificateGraph) = is_co_complete(graph, alphabet(graph))

is_co_complete(graph::_HS.GraphAutomaton, alphabet::AbstractVector) =
    _covers_every_letter(graph, alphabet, _predecessors(graph))

is_co_complete(graph::WordGraph, alphabet::AbstractVector) =
    !has_words(graph) && is_co_complete(_letter_graph(graph), alphabet)

# Whether every node has, in `index`, an entry for every letter. O(|V|·|Σ|) on
# top of the index, which is built once.
function _covers_every_letter(graph::_HS.GraphAutomaton, alphabet, index)
    for node in nodes(graph), letter in alphabet
        haskey(index, (node, letter)) || return false
    end

    return true
end

"""
    _check_path_complete(graph, language)

Throw unless `graph` certifies something for `language` — an alphabet or a
system's automaton, see [`language`](@ref).

Called by every problem's data check. Path-completeness is the soundness
condition, so a graph that fails it must not reach a solver — and it is the
*general* condition, so a graph that is neither complete nor co-complete is
accepted whenever it can still read every word.
"""
function _check_path_complete(graph::CertificateGraph, language)
    is_path_complete(graph, language) || throw(
        ArgumentError(
            "the graph is not path-complete for the system's switching language, " *
            "so its edge inequalities certify nothing; the graph reads the modes " *
            "$(sort(alphabet(graph)))",
        ),
    )

    return nothing
end
