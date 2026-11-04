# The default threshold below which a slack counts as tight. A bisection stops
# above the optimal rate, within `rtol`, so the edges that block a smaller rate
# keep a slack of about `rtol`, not zero. To count them as tight, `atol` must be
# well above `rtol`: `refine` requires `atol ≥ 10 rtol`.
const _TIGHT_ATOL = 1e-4

"""
    tight_edges(certificate; atol = 1e-4)

The edges of the certificate's graph whose slack is at most `atol`, in
`edges(get_graph(certificate))` order. For stability, slacks are relative to the
scale of the node functions, so `atol` compares with the `rtol` of
[`certify`](@ref): read them with `atol` at least ten times `rtol`.
"""
function tight_edges(certificate::AbstractCertificate; atol::Real = _TIGHT_ATOL)
    slacks = edge_slacks(certificate)
    return [
        edge for
        (edge, slack) in zip(edges(get_graph(certificate)), slacks) if slack <= atol
    ]
end

"""
    tight_subgraph(certificate; atol = 1e-4)

The subgraph, on the same nodes, of the edges whose slack is at most `atol`.
"""
function tight_subgraph(certificate::AbstractCertificate; atol::Real = _TIGHT_ATOL)
    graph = get_graph(certificate)
    subgraph = _empty_like(graph, n_nodes(graph))

    for edge in tight_edges(certificate; atol = atol)
        add_edge!(subgraph, source(edge), dest(edge), label(graph, edge))
    end

    return subgraph
end
