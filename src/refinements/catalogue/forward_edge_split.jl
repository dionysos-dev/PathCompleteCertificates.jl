"""
    ForwardEdgeSplit()

Split the source of each given edge into a copy owning that outgoing edge and
every incoming edge; a given self-loop goes from its copy to the node. A node
whose outgoing edges are all given is replaced by its copies, which are
numbered last.
"""
struct ForwardEdgeSplit <: AbstractRefinement end

function refine(
    ::ForwardEdgeSplit,
    g::CertificateGraph,
    edge_list::AbstractVector{<:_HS.GraphTransition},
)
    _check_edge_list(g, edge_list)
    chosen = Set(edge_list)

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
    for edge in edge_list
        push!(origin, source(edge))
        copy_of[edge] = length(origin)
    end

    images = [Int[] for _ in nodes(g)]
    copies = [Int[] for _ in nodes(g)]
    for node in nodes(g)
        keeps[node] && push!(images[node], survivor[node])
    end
    for edge in edge_list
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
