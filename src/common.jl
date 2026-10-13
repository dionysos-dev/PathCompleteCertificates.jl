"""
    common(template, graph, problem, Vs, x)

The common function of the node functions `Vs` on `graph`, evaluated at `x`: a
minimum of maxima of the `Vs` [philippe2017path](@cite). Depending on `problem`,
a common Lyapunov function, a common barrier function or a bound on the value
function. Calling a certificate `c` as `c(x)` evaluates it with the node
functions of `c`.
"""
function common(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::AbstractProblem,
    Vs::AbstractVector,
    x::AbstractVector{<:Real},
)
    # Special cases of the observer construction below, cheaper to evaluate.
    alphabet = 1:_n_modes(problem)

    if is_complete(graph, alphabet)
        return minimum(node_value(template, problem, V, x) for V in Vs)
    elseif is_co_complete(graph, alphabet)
        return maximum(node_value(template, problem, V, x) for V in Vs)
    end

    # Each observer node is a set of nodes: maximum within, minimum across.
    _, observer_states = observer_graph(graph, alphabet)

    return minimum(
        maximum(node_value(template, problem, Vs[node], x) for node in state) for
        state in observer_states
    )
end

# No state is constrained inside a word, so a word graph has no common function.
function common(
    template::AbstractTemplate,
    graph::WordGraph,
    problem::AbstractProblem,
    Vs::AbstractVector,
    x::AbstractVector{<:Real},
)
    return common(template, _letter_graph(graph, "common"), problem, Vs, x)
end
