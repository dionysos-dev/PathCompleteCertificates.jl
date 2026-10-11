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
