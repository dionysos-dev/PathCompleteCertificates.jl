# The dual graph: every edge reversed, every word reversed.
# Path-completeness is preserved.

dual(graph::CertificateGraph) = first(_dual_with_images(graph))

"""
    dual(graph, edge_list) -> (dual_graph, dual_edge_list)

The dual graph, and for each edge `s → d` of `edge_list` the reversed edge
`d → s` of the dual graph, in the same order.
"""
function dual(graph::CertificateGraph, edge_list::AbstractVector{<:_HS.GraphTransition})
    dualised, image = _dual_with_images(graph)

    return dualised, [image[edge] for edge in edge_list]
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
