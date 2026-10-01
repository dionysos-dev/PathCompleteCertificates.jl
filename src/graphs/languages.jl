# The language a certificate graph must read is the system's: every word over
# its modes under arbitrary switching, the paths of its automaton otherwise
# (Philippe, Essick, Dullerud & Jungers, 2016). Constrained switching is then
# not a separate theory but a second kind of language for the same predicate.

"""
    language(system)

The switching language of `system`, as its automaton: a `OneStateAutomaton`
reading every word over the modes when switching is arbitrary, the constraint
automaton passed to [`switched_system`](@ref) otherwise.

This is what [`is_path_complete`](@ref) must be asked against when the question
is about a certificate, and every problem asks it.
"""
language(system::_HS.HybridSystem) = system.automaton

is_path_complete(graph::CertificateGraph, automaton::_HS.OneStateAutomaton) =
    is_path_complete(graph, 1:_HS.ntransitions(automaton))

function is_path_complete(graph::_HS.GraphAutomaton, constraint::_HS.GraphAutomaton)
    letters = alphabet(constraint)

    # A graph reading every word reads any language over the same letters.
    (is_complete(graph, letters) || is_co_complete(graph, letters)) && return true

    index = successors(graph)

    # The subset construction in product with the constraint: a state is a node
    # of the constraint and the set of graph nodes that can have read the same
    # path. Every word the constraint accepts from any of its states must keep
    # that set nonempty.
    seen = Set{Tuple{Int, Tuple{Vararg{Int}}}}()
    pending = Tuple{Int, Set{Int}}[]

    for q in nodes(constraint)
        start = Set(nodes(graph))
        push!(seen, (q, Tuple(sort!(collect(start)))))
        push!(pending, (q, start))
    end

    while !isempty(pending)
        q, subset = pop!(pending)

        for transition in outgoing_edges(constraint, q)
            reachable = _step(index, subset, label(constraint, transition))

            isempty(reachable) && return false

            key = (dest(transition), Tuple(sort!(collect(reachable))))
            if !(key in seen)
                push!(seen, key)
                push!(pending, (dest(transition), reachable))
            end
        end
    end

    return true
end

is_path_complete(graph::WordGraph, constraint::_HS.GraphAutomaton) =
    is_path_complete(first(expanded_form(graph)), constraint)

"""
    seed(system)

The certificate graph refinement starts from: the one-node graph with a loop
per mode under arbitrary switching, and the system's own automaton otherwise.

Both read the system's [`language`](@ref) by construction — the automaton is
the multinorm's graph of Philippe, Essick, Dullerud & Jungers, one function per
state — and every lift preserves that, so a run from the seed never re-decides
path-completeness.
"""
seed(system::_HS.HybridSystem) = seed(language(system))

function seed(automaton::_HS.OneStateAutomaton)
    graph = empty_graph(1)

    for mode in 1:_HS.ntransitions(automaton)
        add_edge!(graph, 1, 1, mode)
    end

    return graph
end

function seed(automaton::_HS.GraphAutomaton)
    graph = empty_graph(n_nodes(automaton))

    for edge in edges(automaton)
        add_edge!(graph, source(edge), dest(edge), label(automaton, edge))
    end

    return graph
end
