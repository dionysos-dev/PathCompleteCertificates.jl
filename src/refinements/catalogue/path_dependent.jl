"""
    PathDependentRefinement(k)

The path-dependent lift of order `k` (Philippe, Essick, Dullerud & Jungers,
Def. 3): [`BackwardEdgeSplit`](@ref) at every edge, `k` times. Its nodes are
the paths of length `k` of the original graph and its edges the paths of
length `k + 1`. From the one-node graph it is [`de_bruijn`](@ref)`(k, M)`, and
its [`dual`](@ref) the dual De Bruijn graph; from a constraint automaton, the
`k`-memory lift of the constrained system. `origins` record the last node of
each path.
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
