"""
    expanded_form(graph)

The graph with one mode per edge obtained by breaking every word edge
`(a, b, i₁…iₖ)` into a chain `a → m₁ → ⋯ → mₖ₋₁ → b` through `k − 1` new
nodes. Nodes `1:n_nodes(graph)` keep their number; the new ones follow.
"""
expanded_form(graph::_LetterGraph) = graph

function expanded_form(graph::WordGraph)
    n = n_nodes(graph)
    n_new = sum(edge -> _word_length(graph, edge) - 1, edges(graph); init = 0)

    expanded = empty_graph(n + n_new)
    next = n

    for edge in edges(graph)
        word = label(graph, edge)
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

    return expanded
end
