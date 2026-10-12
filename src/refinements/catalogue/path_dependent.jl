"""
    PathDependentRefinement(k)

[`BackwardEdgeSplit`](@ref) at every edge, `k` times: nodes are the paths of
length `k`, and `origins` records the last node of each.
"""
struct PathDependentRefinement <: AbstractRefinement
    order::Int

    function PathDependentRefinement(order::Integer)
        order >= 1 || throw(ArgumentError("the order must be positive"))
        return new(order)
    end
end

function refine(refinement::PathDependentRefinement, g::CertificateGraph)
    current = g
    origin = collect(nodes(g))

    for _ in 1:(refinement.order)
        step = refine(BackwardEdgeSplit(), current)
        origin = [origin[o] for o in origins(step)]
        current = graph(step)
    end

    return Refined(current, origin)
end
