"""
    common(template, graph, problem, Ps, x)

Evaluate at `x` the common function the node functions `Ps` of a certificate
on `graph` combine into (Philippe, Athanasopoulos, Angeli & Jungers): the
minimum over the nodes on a complete graph (Cor. III.3), the maximum on a
co-complete one, and a minimum of maxima over the observer construction
otherwise (Thm. III.8). Depending on `problem` it is a common Lyapunov
function, a common barrier function, or an upper bound on the value function.
"""
function common(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::AbstractProblem,
    Ps::AbstractVector,
    x::AbstractVector{<:Real},
)
    # Corollary III.3 of Philippe et al.: a complete graph combines with a
    # minimum, a co-complete one with a maximum. Both are special cases of the
    # observer construction below (Theorem III.8), taken here because they are
    # cheaper and need no subset construction.
    alphabet = 1:_n_modes(problem)

    if is_complete(graph, alphabet)
        return minimum(node_value(template, problem, P, x) for P in Ps)
    elseif is_co_complete(graph, alphabet)
        return maximum(node_value(template, problem, P, x) for P in Ps)
    end

    # Each observer node is a *set* of nodes of `graph`, so the common function is
    # a maximum within each set and a minimum across them.
    _, observer_states = observer_graph(graph)

    return minimum(
        maximum(node_value(template, problem, Ps[node], x) for node in state) for
        state in observer_states
    )
end

# A word graph has no state at the silent steps inside a word, so no observer
# and no common function; expand it first.
function common(
    ::AbstractTemplate,
    graph::WordGraph,
    ::AbstractProblem,
    ::AbstractVector,
    ::AbstractVector{<:Real},
)
    return _require_letters(graph, "common")
end
