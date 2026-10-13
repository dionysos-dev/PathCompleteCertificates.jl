# How close to zero a slack counts as tight, by default. A certificate from a
# bisection stopped at relative tolerance `rtol` keeps slacks of order `rtol` on
# its active edges, so read it with `atol ≥ 10 rtol`, as `refine` requires.
const _TIGHT_ATOL = 1e-4

"""
    tight_edges(certificate; atol = 1e-4)

The edges of the certificate's graph whose slack is at most `atol`, in
`edges(graph(certificate))` order. `atol` is absolute, so its meaning depends on
the scale of the certificate.
"""
function tight_edges(certificate::AbstractCertificate; atol::Real = _TIGHT_ATOL)
    slacks = edge_slacks(certificate)
    return [
        edge for (edge, slack) in zip(edges(graph(certificate)), slacks) if slack <= atol
    ]
end

"""
    tight_subgraph(certificate; atol = 1e-4)

The subgraph, on the same nodes, of the edges whose slack is at most `atol`.
"""
function tight_subgraph(certificate::AbstractCertificate; atol::Real = _TIGHT_ATOL)
    graph_ = graph(certificate)
    subgraph = _empty_like(graph_, n_nodes(graph_))

    for edge in tight_edges(certificate; atol = atol)
        add_edge!(subgraph, source(edge), dest(edge), label(graph_, edge))
    end

    return subgraph
end
