"""
    ForwardProductLift()

Replace each given edge `(s, d, w)` by the edges `(s, d′, w·u)` for every
edge `(d, d′, u)`, in a [`WordGraph`](@ref) on the same nodes: the partial
T-lift of [athanasopoulos2019polyhedral; Def. 4](@cite). Throws when `d` has
no outgoing edge. No requirement: two chained edge inequalities imply the
product's.
"""
struct ForwardProductLift <: AbstractLift end

function lift(
    ::ForwardProductLift,
    g::CertificateGraph,
    edge_list::AbstractVector{<:_HS.GraphTransition},
)
    _check_edge_list(g, edge_list)
    chosen = Set(edge_list)
    lifted = WordGraph(n_nodes(g))
    seen = Set{Tuple{Int, Int, Vector{Int}}}()

    add!(s, d, word) =
        (s, d, word) in seen || (push!(seen, (s, d, word)); add_edge!(lifted, s, d, word))

    for edge in edges(g)
        word = collect(Int, letters(label(g, edge)))

        if edge in chosen
            continuations = outgoing_edges(g, dest(edge))
            isempty(continuations) && throw(
                ArgumentError(
                    "node $(dest(edge)) has no outgoing edge; the edge into it " *
                    "cannot be folded forward",
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
