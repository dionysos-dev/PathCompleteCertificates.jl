# The dual graph: every edge reversed, every word reversed (Debauche, Def. 6.3).
# Path-completeness is preserved (Prop. 6.6), and a certificate on the dual
# graph for the transposed system in the dual template is a certificate on the
# original (Lemma 6.25) -- which is what makes every "backward" lift the dual of
# a "forward" one.

dual(graph::CertificateGraph) = first(_dual_with_images(graph))

"""
    dual(graph, edges) -> (dual_graph, dual_edges)

The dual graph together with the edges of it that `edges` became, in order.

The edges of a rebuilt graph are new objects, and the backing store lists them
in no particular order, so a lift applied at a locus of the dual graph needs
the correspondence recorded as the dual is built.
"""
function dual(graph::CertificateGraph, locus::AbstractVector{<:_HS.GraphTransition})
    dualised, image = _dual_with_images(graph)

    return dualised, [image[edge] for edge in locus]
end

# The dual graph and, for every edge of the original, the reversed edge it
# became.
function _dual_with_images(graph::CertificateGraph)
    dualised = _empty_like(graph, n_nodes(graph))
    image = Dict{_HS.GraphTransition, _HS.GraphTransition}()

    for edge in edges(graph)
        image[edge] =
            add_edge!(dualised, dest(edge), source(edge), _reversed(label(graph, edge)))
    end

    return dualised, image
end

_reversed(mode::Integer) = mode
_reversed(word::AbstractVector{<:Integer}) = reverse(word)
