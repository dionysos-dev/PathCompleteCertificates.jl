# The common function as a graph construction [philippe2017path]: from the values
# of the node functions at one point, their minimum on a complete graph
# (Cor. III.3), their maximum on a co-complete one, and otherwise the minimum
# over the observer states of the maximum within each (Thm. III.8). A word graph
# has none: no state is constrained inside a word.
function _common(graph::CertificateGraph, alphabet::AbstractVector, values::AbstractVector)
    letters = _letter_graph(graph, "common")

    is_complete(letters, alphabet) && return minimum(values)
    is_co_complete(letters, alphabet) && return maximum(values)

    _, states = observer_graph(letters, alphabet)

    return minimum(maximum(values[node] for node in state) for state in states)
end
