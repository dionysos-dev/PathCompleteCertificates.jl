"""
    PathDependentLift(k)

The `k`-path-dependent lift of [philippe2016stability; Def. 3](@cite), their
`M`-path-dependent lifting: [`InSplitLift`](@ref) at every edge, `k` times.
Its nodes are the paths of length `k`, and `origins` records the last node of
each. From the common graph it is [`de_bruijn`](@ref)`(k, n_modes)` up to the
numbering of the nodes.
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
        current = get_graph(step)
    end

    return Lifted(current, origin)
end
