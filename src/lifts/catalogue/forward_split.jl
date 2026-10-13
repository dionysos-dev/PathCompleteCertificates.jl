"""
    ForwardSplitLift()

Split a node into copies that each receive every incoming edge and own part of
its outgoing edges.

- `lift(ForwardSplitLift(), graph, node)` is the forward lift of
  [ninite2026lifting; Def. 3](@cite): one copy of `node` per successor, owning
  every edge to that successor; a self-loop leaves the copy that owns it for
  every copy.
- `lift(ForwardSplitLift(), graph, edges)` is the partial P\\*-lift of
  [athanasopoulos2019polyhedral; Def. 7](@cite) at each edge: one copy of its
  source owning that edge. A node whose outgoing edges are all given is
  replaced by its copies; otherwise a given self-loop goes from its copy to the
  node.

The two agree unless two outgoing edges of the node share a destination.
Copies are numbered last. No requirement: each copy takes the function of the
node it came from.
"""
struct ForwardSplitLift <: AbstractLift end

function lift(::ForwardSplitLift, g::CertificateGraph, edge_list::AbstractVector{<:_Edge})
    _check_edge_list(g, edge_list)
    return _split(g, [[edge] for edge in edge_list])
end

function lift(::ForwardSplitLift, g::CertificateGraph, node::Integer)
    out = outgoing_edges(g, node)
    isempty(out) && throw(ArgumentError("node $node has no successor to split it along"))

    successors = sort!(unique(dest.(out)))
    return _split(g, [filter(edge -> dest(edge) == w, out) for w in successors])
end

# At an edge, a second outgoing edge must stay with the node; at a node, a
# second successor must get its own copy.
_changes(::ForwardSplitLift, g::CertificateGraph, edge::_Edge) =
    outdegree(g, source(edge)) >= 2
_changes(::ForwardSplitLift, g::CertificateGraph, node::Integer) =
    length(unique(dest.(outgoing_edges(g, node)))) >= 2

# One copy of the source per group of outgoing edges, owning the group.
function _split(g::CertificateGraph, groups::AbstractVector)
    chosen = Set(Iterators.flatten(groups))

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

    images = [Int[] for _ in nodes(g)]
    copies = [Int[] for _ in nodes(g)]
    for node in nodes(g)
        keeps[node] && push!(images[node], survivor[node])
    end

    copy_of = Dict{_Edge, Int}()
    for group in groups
        s = source(first(group))
        push!(origin, s)
        push!(images[s], length(origin))
        push!(copies[s], length(origin))
        for edge in group
            copy_of[edge] = length(origin)
        end
    end

    lifted = _empty_like(g, length(origin))

    for edge in edges(g)
        s, d, word = source(edge), dest(edge), label(g, edge)

        if edge in chosen && s == d && keeps[s]
            add_edge!(lifted, copy_of[edge], survivor[s], word)
            for copy in copies[s]
                add_edge!(lifted, survivor[s], copy, word)
            end
            continue
        end

        from = edge in chosen ? copy_of[edge] : survivor[s]
        for to in images[d]
            add_edge!(lifted, from, to, word)
        end
    end

    return Lifted(lifted, origin)
end
