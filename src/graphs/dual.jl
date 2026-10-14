"""
    dual(x)

The dual of a graph, lift, operation, template, system, problem or certificate;
`dual(template, V)` is the dual of one node function.
"""
function dual end

"""
    dual(graph)

The dual graph: every edge `s → d` reversed into `d → s`, every word reversed.
Path-completeness is preserved.
"""
dual(graph::CertificateGraph) = first(_dual_with_images(graph))

# The dual graph and, for every edge of the original, the reversed edge it
# became.
function _dual_with_images(graph::CertificateGraph)
    dualised = _empty_like(graph, n_nodes(graph))
    image = Dict{_Edge, _Edge}()

    for edge in edges(graph)
        image[edge] =
            add_edge!(dualised, dest(edge), source(edge), _reversed(label(graph, edge)))
    end

    return dualised, image
end

_reversed(mode::Integer) = mode
_reversed(word::AbstractVector{<:Integer}) = reverse(word)
