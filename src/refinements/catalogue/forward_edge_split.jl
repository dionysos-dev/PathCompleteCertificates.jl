"""
    ForwardEdgeSplit()

Split the source of each edge of the locus: a copy of it owning that one
outgoing edge and every incoming edge (Athanasopoulos & Jungers, Def. 7, the
partial P\\*-lift). Every incoming edge of a split node enters every copy, a
self-loop included; an outgoing edge leaves the copy that owns it, or the node
itself when it is not in the locus; a self-loop in the locus returns from its
copy to the node. A node whose outgoing edges are all in the locus is replaced
by its copies, and a node left without edges is deleted. Copies are numbered
last.

At one edge this is the paper's lift; a locus of several edges at one node is
that lift applied edge by edge, the loop last. On `outgoing_edges(graph, s)`,
the default step of [`refine`](@ref), it gives `s` one copy per outgoing edge,
which is the forward lift of Ninite & Jungers (Def. 3) whenever no two edges
of `s` share a destination; their lift gives one copy per successor instead.
Its dual, [`BackwardEdgeSplit`](@ref), splits destinations along incoming
edges.
"""
struct ForwardEdgeSplit <: AbstractRefinement end

function refine(
    ::ForwardEdgeSplit,
    g::CertificateGraph,
    locus::AbstractVector{<:_HS.GraphTransition},
)
    _check_locus(g, locus)
    chosen = Set(locus)

    keeps = falses(n_nodes(g))
    for edge in edges(g)
        edge in chosen || (keeps[source(edge)] = true)
    end

    survivor = zeros(Int, n_nodes(g))
    origin = Int[]
    for node in nodes(g)
        keeps[node] || continue
        push!(origin, node)
        survivor[node] = length(origin)
    end

    copy_of = Dict{_HS.GraphTransition, Int}()
    for edge in locus
        push!(origin, source(edge))
        copy_of[edge] = length(origin)
    end

    images = [Int[] for _ in nodes(g)]
    copies = [Int[] for _ in nodes(g)]
    for node in nodes(g)
        keeps[node] && push!(images[node], survivor[node])
    end
    for edge in locus
        push!(images[source(edge)], copy_of[edge])
        push!(copies[source(edge)], copy_of[edge])
    end

    refined = _empty_like(g, length(origin))

    for edge in edges(g)
        s, d, word = source(edge), dest(edge), label(g, edge)

        if edge in chosen && s == d && keeps[s]
            add_edge!(refined, copy_of[edge], survivor[s], word)
            for copy in copies[s]
                add_edge!(refined, survivor[s], copy, word)
            end
            continue
        end

        from = edge in chosen ? copy_of[edge] : survivor[s]
        for to in images[d]
            add_edge!(refined, from, to, word)
        end
    end

    return Refined(refined, origin)
end
