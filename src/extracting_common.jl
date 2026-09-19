"""
    common(template, graph, problem, Ps, x)

Evaluate the common function associated with `graph` at `x`. Complete graphs
use the minimum over the node functions, co-complete graphs use the maximum,
and other graphs use the observer construction with the corresponding
minimum-maximum aggregation. Depending on `problem`, this function represents
a common Lyapunov function for stability, a common barrier function for
safety, or an upper bound on the value function for optimal control.
"""
function common(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::AbstractProblem,
    Ps::AbstractVector,
    x::AbstractVector{<:Real},
)
    # Corollary III.3 of Philippe et al.: a complete graph aggregates with a
    # minimum, a co-complete one with a maximum. Both are special cases of the
    # observer construction below (Theorem III.8), taken here because they are
    # cheaper and need no subset construction.
    alphabet = 1:_n_modes(problem)

    if is_complete(graph, alphabet)
        return minimum(_node_value(template, problem, P, x) for P in Ps)
    elseif is_co_complete(graph, alphabet)
        return maximum(_node_value(template, problem, P, x) for P in Ps)
    end

    # Each observer node is a *set* of nodes of `graph`, so the aggregation is
    # a maximum within each set and a minimum across them.
    _, observer_states = observer_graph(graph)

    return minimum(
        maximum(_node_value(template, problem, Ps[node], x) for node in state) for
        state in observer_states
    )
end

"""
    _node_value(template, problem, V, x)

Evaluate one node function at `x`.

Defined per template, with a problem argument only because a problem may lift
the function into other coordinates — `SafetyProblem` evaluates its barriers in
homogeneous coordinates, which is the one case where the pair matters.
"""
function _node_value end

function _node_value(
    template::AbstractTemplate,
    problem::AbstractProblem,
    V,
    ::AbstractVector{<:Real},
)
    return throw(
        ArgumentError(
            "no node-function evaluation for $(typeof(template)) on " *
            "$(nameof(typeof(problem))); define `_node_value` for that pair",
        ),
    )
end
