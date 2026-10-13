"""
    ProductLift(T)

The `T`-product lift of [philippe2016stability; Def. 2](@cite): the same nodes,
and one edge per path of length `T` labelled by its word, as a
[`WordGraph`](@ref). Its own dual.
"""
struct ProductLift <: AbstractLift
    length::Int

    function ProductLift(length::Integer)
        length >= 1 || throw(ArgumentError("the length must be positive"))
        return new(length)
    end
end

dual(L::ProductLift) = L

function lift(L::ProductLift, g::CertificateGraph)
    lifted = WordGraph(n_nodes(g))
    seen = Set{Tuple{Int, Int, Vector{Int}}}()

    function extend(start, current, word, remaining)
        if remaining == 0
            _add_once!(lifted, seen, start, current, word)
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
        extend(node, node, Int[], L.length)
    end

    return Lifted(lifted, collect(nodes(g)))
end
