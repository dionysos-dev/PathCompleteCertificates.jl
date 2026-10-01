# Words on edges, and the letter graph that reads the same language.

"""
    expanded_form(graph) -> (letter_graph, origins)

The letter graph obtained by breaking every word edge `(s, d, i₁…iₖ)` into a
chain `s → m₁ → ⋯ → mₖ₋₁ → d` of one-mode edges through `k − 1` fresh nodes
(Ahmadi et al. 2014, Def. 2.1; Debauche, Def. 6.7).

`origins[m]` is the node of `graph` a node `m` came from, and `0` for a fresh
one. A letter graph expands to itself.

A word graph is path-complete exactly when its expanded form is, which is how
[`is_path_complete`](@ref) decides it. The two certify the same rate for a
template closed under composition with the dynamics, the word graph with fewer
variables (Debauche, Prop. 7.70).
"""
expanded_form(graph::_HS.GraphAutomaton) = (graph, collect(nodes(graph)))

function expanded_form(graph::WordGraph)
    n = n_nodes(graph)
    fresh = sum(edge -> word_length(graph, edge) - 1, edges(graph); init = 0)

    expanded = empty_graph(n + fresh)
    origins = [collect(nodes(graph)); zeros(Int, fresh)]
    next = n

    for edge in edges(graph)
        word = letters(label(graph, edge))
        previous = source(edge)

        for (k, mode) in enumerate(word)
            if k == length(word)
                add_edge!(expanded, previous, dest(edge), mode)
            else
                next += 1
                add_edge!(expanded, previous, next, mode)
                previous = next
            end
        end
    end

    return expanded, origins
end
