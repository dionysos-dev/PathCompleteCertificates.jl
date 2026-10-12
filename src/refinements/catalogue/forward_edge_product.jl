"""
    ForwardEdgeProduct()

Replace each edge `(s, d, w)` of the locus by the edges `(s, d′, w·u)` for every
edge `(d, d′, u)` leaving its destination (Athanasopoulos & Jungers, Def. 4, the
partial T-lift). The result is a [`WordGraph`](@ref): one inequality on a
product of modes replaces one on a single step, and no node is added. At every
edge this is [`ProductRefinement`](@ref)`(2)`; its dual,
[`BackwardEdgeProduct`](@ref), folds an edge into the edges entering its
source.
"""
struct ForwardEdgeProduct <: AbstractRefinement end

function refine(
    ::ForwardEdgeProduct,
    g::CertificateGraph,
    locus::AbstractVector{<:_HS.GraphTransition},
)
    _check_locus(g, locus)
    chosen = Set(locus)
    refined = WordGraph(n_nodes(g))
    seen = Set{Tuple{Int, Int, Vector{Int}}}()

    add!(s, d, word) =
        (s, d, word) in seen || (push!(seen, (s, d, word)); add_edge!(refined, s, d, word))

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

    return Refined(refined, collect(nodes(g)))
end
