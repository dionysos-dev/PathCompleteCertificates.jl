# Splitting a node along its edges: the partial P*-lift of Athanasopoulos &
# Jungers (Def. 7) at one edge, the forward lift of Ninite & Jungers (Def. 3)
# on a node's out-star, and the path-dependent lift of Philippe, Essick,
# Dullerud & Jungers (Def. 3) on every edge of the graph -- one operation,
# three loci.

"""
    ForwardEdgeSplit()

Split the source of each edge of the locus: a copy of it owning that one
outgoing edge and every incoming edge (Athanasopoulos & Jungers, Def. 7, the
partial P\\*-lift).

Applied simultaneously at a locus. Every incoming edge of a split node, a
self-loop included, enters every copy; an outgoing edge leaves the copy that
owns it, or the node itself when it is not in the locus; a self-loop owned by a
copy leaves it towards every copy. A node whose outgoing edges are all in the
locus is replaced by its copies. Copies are numbered last.

On `outgoing_edges(graph, s)` this is the node split of Ninite & Jungers at the
edge grain, which [`refine`](@ref) uses by default. Its dual,
[`BackwardEdgeSplit`](@ref), splits destinations along incoming edges, and on
`edges(graph)` is [`MemoryLift`](@ref)`(1)`.

Valid for every template: a copy inherits its origin's function.
"""
struct ForwardEdgeSplit <: AbstractLift end

scope(::ForwardEdgeSplit) = Local()

function (::ForwardEdgeSplit)(
    g::CertificateGraph,
    locus::AbstractVector{<:_HS.GraphTransition},
)
    _check_locus(g, locus)

    chosen = Set(locus)

    # A node survives when it keeps an outgoing edge; it is renumbered first.
    keeps = falses(n_nodes(g))
    for edge in edges(g)
        edge in chosen || (keeps[source(edge)] = true)
    end

    survivor = zeros(Int, n_nodes(g))
    origins = Int[]
    for node in nodes(g)
        keeps[node] || continue
        push!(origins, node)
        survivor[node] = length(origins)
    end

    # Then one copy per locus edge, owning it.
    copy_of = Dict{_HS.GraphTransition, Int}()
    for edge in locus
        push!(origins, source(edge))
        copy_of[edge] = length(origins)
    end

    # Every image of a node: itself if it survives, and its copies.
    images = [Int[] for _ in nodes(g)]
    for node in nodes(g)
        keeps[node] && push!(images[node], survivor[node])
    end
    for edge in locus
        push!(images[source(edge)], copy_of[edge])
    end

    lifted = _empty_like(g, length(origins))

    for edge in edges(g)
        from = edge in chosen ? copy_of[edge] : survivor[source(edge)]
        for to in images[dest(edge)]
            add_edge!(lifted, from, to, label(g, edge))
        end
    end

    return Lifted(lifted, origins)
end

"""
    BackwardEdgeSplit()

Split the destination of each edge of the locus: a copy of it owning that one
incoming edge and every outgoing edge (Athanasopoulos & Jungers, Def. 6, the
partial P-lift). The dual of [`ForwardEdgeSplit`](@ref), and on `edges(graph)`
the path-dependent lift of Philippe, Essick, Dullerud & Jungers — nodes become
the edges, edges the paths of length two.
"""
const BackwardEdgeSplit = DualLift{ForwardEdgeSplit}

BackwardEdgeSplit() = DualLift(ForwardEdgeSplit())

"""
    MemoryLift(k)

The path-dependent lift of order `k` (Philippe, Essick, Dullerud & Jungers,
Def. 3): [`BackwardEdgeSplit`](@ref) at every edge, `k` times. Its nodes are
the paths of length `k` of the original graph and its edges the paths of length
`k + 1`.

From the one-node graph it is [`de_bruijn`](@ref)`(k, M)`; from a constraint
automaton it is the `k`-memory lift of the constrained system. Valid for every
template. `origins` record the last node of each path.
"""
struct MemoryLift <: AbstractLift
    order::Int

    function MemoryLift(order::Integer)
        order >= 1 || throw(ArgumentError("the order must be positive"))
        return new(order)
    end
end

scope(::MemoryLift) = Global()

function (lift::MemoryLift)(g::CertificateGraph)
    current = g
    origins = collect(nodes(g))

    for _ in 1:(lift.order)
        step = BackwardEdgeSplit()(current, collect(edges(current)))
        origins = [origins[origin] for origin in step.origins]
        current = graph(step)
    end

    return Lifted(current, origins)
end
