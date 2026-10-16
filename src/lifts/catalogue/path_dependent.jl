"""
    PathDependentLift(M)

The `M`-path-dependent lift of [philippe2016stability; Def. 3](@cite):
[`InSplitLift`](@ref) at every edge, `M` times. Its nodes are the paths
of length `M`, and `origins` records the last node of each. From the one-node
graph it is [`de_bruijn`](@ref)`(M, n_modes)` up to the numbering of the
nodes.
"""
struct PathDependentLift <: AbstractLift
    order::Int

    function PathDependentLift(order::Integer)
        order >= 1 || throw(ArgumentError("the order must be positive"))
        return new(order)
    end
end

function lift(L::PathDependentLift, g::CertificateGraph)
    current = g
    origin = collect(nodes(g))

    for _ in 1:(L.order)
        step = lift(InSplitLift(), current)
        origin = [origin[o] for o in origins(step)]
        current = graph(step)
    end

    return Lifted(current, origin)
end
