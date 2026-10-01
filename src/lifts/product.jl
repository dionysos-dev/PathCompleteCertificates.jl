# Folding an edge into its neighbours: the partial T-lift of Athanasopoulos &
# Jungers (Def. 4) at one edge, and the T-product lift of Philippe, Essick,
# Dullerud & Jungers (Def. 2) on every edge -- memory added on the edges, as
# words, rather than on the nodes.

"""
    ForwardEdgeProduct()

Replace each edge `(s, d, w)` of the locus by the edges `(s, d′, w·u)` for every
edge `(d, d′, u)` leaving its destination (Athanasopoulos & Jungers, Def. 4, the
partial T-lift). The result is a [`WordGraph`](@ref).

One inequality on a product of modes replaces one on a single step, and no
node is added: the certificate gains memory on its edges. Applied at every edge
this is [`ProductLift`](@ref)`(2)`. Its dual, [`BackwardEdgeProduct`](@ref),
folds an edge into the edges entering its source.

Valid for every template — two chained edge inequalities imply the product's
(Athanasopoulos & Jungers, Thm. 1). Path-completeness is preserved in the factor
sense, which is what a word graph is asked for.
"""
struct ForwardEdgeProduct <: AbstractLift end

scope(::ForwardEdgeProduct) = Local()

function (::ForwardEdgeProduct)(
    g::CertificateGraph,
    locus::AbstractVector{<:_HS.GraphTransition},
)
    _check_locus(g, locus)

    chosen = Set(locus)
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

"""
    BackwardEdgeProduct()

Replace each edge `(s, d, w)` of the locus by the edges `(s′, d, u·w)` for every
edge `(s′, s, u)` entering its source (Athanasopoulos & Jungers, Def. 5, the
partial T\\*-lift). The dual of [`ForwardEdgeProduct`](@ref).
"""
const BackwardEdgeProduct = DualLift{ForwardEdgeProduct}

BackwardEdgeProduct() = DualLift(ForwardEdgeProduct())

"""
    ProductLift(T)

The `T`-product lift (Philippe, Essick, Dullerud & Jungers, Def. 2): the same
nodes, one edge per path of length `T`, reading the concatenated word. A
[`WordGraph`](@ref).

`ProductLift(2)` is [`ForwardEdgeProduct`](@ref) at every edge, and equally
[`BackwardEdgeProduct`](@ref) at every edge; the product lift is self-dual.
Valid for every template.
"""
struct ProductLift <: AbstractLift
    length::Int

    function ProductLift(length::Integer)
        length >= 1 || throw(ArgumentError("the length must be positive"))
        return new(length)
    end
end

scope(::ProductLift) = Global()

function (lift::ProductLift)(g::CertificateGraph)
    lifted = WordGraph(n_nodes(g))
    seen = Set{Tuple{Int, Int, Vector{Int}}}()

    function extend(start, current, word, remaining)
        if remaining == 0
            key = (start, current, word)
            key in seen || (push!(seen, key); add_edge!(lifted, start, current, word))
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
        extend(node, node, Int[], lift.length)
    end

    return Lifted(lifted, collect(nodes(g)))
end
