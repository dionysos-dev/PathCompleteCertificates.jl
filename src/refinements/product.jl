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

scope(::ForwardEdgeProduct) = Local()

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

"""
    BackwardEdgeProduct()

Replace each edge `(s, d, w)` of the locus by the edges `(s′, d, u·w)` for every
edge `(s′, s, u)` entering its source (Athanasopoulos & Jungers, Def. 5, the
partial T\\*-lift). The dual of [`ForwardEdgeProduct`](@ref).
"""
const BackwardEdgeProduct = DualRefinement{ForwardEdgeProduct}

BackwardEdgeProduct() = DualRefinement(ForwardEdgeProduct())

"""
    ProductRefinement(T)

The `T`-product lift (Philippe, Essick, Dullerud & Jungers, Def. 2): the same
nodes, one edge per path of length `T`, reading the concatenated word. A
[`WordGraph`](@ref). `ProductRefinement(2)` is either edge product at every
edge; the construction is self-dual.
"""
struct ProductRefinement <: AbstractRefinement
    length::Int

    function ProductRefinement(length::Integer)
        length >= 1 || throw(ArgumentError("the length must be positive"))
        return new(length)
    end
end

scope(::ProductRefinement) = Global()

dual(refinement::ProductRefinement) = refinement

function refine(refinement::ProductRefinement, g::CertificateGraph)
    refined = WordGraph(n_nodes(g))
    seen = Set{Tuple{Int, Int, Vector{Int}}}()

    function extend(start, current, word, remaining)
        if remaining == 0
            key = (start, current, word)
            key in seen || (push!(seen, key); add_edge!(refined, start, current, word))
            return nothing
        end

        for edge in outgoing_edges(g, current)
            extend(
                start,
                dest(edge),
                vcat(word, collect(Int, letters(label(g, edge)))),
                remaining - 1,
            )
        end

        return nothing
    end

    for node in nodes(g)
        extend(node, node, Int[], refinement.length)
    end

    return Refined(refined, collect(nodes(g)))
end
