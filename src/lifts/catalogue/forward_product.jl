"""
    ForwardProductLift()

Replace each given edge `(a, b, w)` by the edges `(a, b′, w·u)` for every
edge `(b, b′, u)`, in a [`WordGraph`](@ref) on the same nodes: the partial
T-lift of [athanasopoulos2019polyhedral; Def. 4](@cite). Throws when `b` has
no outgoing edge. No requirement: two chained edge inequalities imply the
product's.
"""
struct ForwardProductLift <: AbstractLift end

function lift(::ForwardProductLift, g::CertificateGraph, edge_list::AbstractVector{<:_Edge})
    _check_edge_list(g, edge_list)
    chosen = Set(edge_list)
    lifted = WordGraph(n_nodes(g))
    seen = Set{Tuple{Int, Int, Vector{Int}}}()
    add!(s, d, word) = _add_once!(lifted, seen, s, d, word)

    for edge in edges(g)
        word = collect(Int, letters(label(g, edge)))

        if edge in chosen
            continuations = outgoing_edges(g, dest(edge))
            isempty(continuations) && throw(
                ArgumentError(
                    "node $(dest(edge)) has no edge to chain with the given " *
                    "edge, so it cannot be folded",
                ),
            )

            for next in continuations
                add!(
                    source(edge),
                    dest(next),
                    vcat(word, collect(Int, letters(label(g, next)))),
                )
            end
        else
            add!(source(edge), dest(edge), word)
        end
    end

    return Lifted(lifted, collect(nodes(g)))
end

# The destination needs an edge to continue with.
_changes(::ForwardProductLift, g::CertificateGraph, edge::_Edge) =
    outdegree(g, dest(edge)) >= 1
