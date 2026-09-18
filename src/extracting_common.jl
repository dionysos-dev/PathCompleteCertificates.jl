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
    template::Type{QuadraticTemplate},
    graph::_HS.GraphAutomaton,
    problem::AbstractProblem,
    Ps::AbstractVector{<:AbstractMatrix},
    x::AbstractVector{<:Real},
)
    if is_complete(graph)
        return minimum(_node_value(template, problem, P, x) for P in Ps)
    elseif is_co_complete(graph)
        return maximum(_node_value(template, problem, P, x) for P in Ps)
    end

    _, obs_states = observer_graph(graph)
    vals = [_node_value(template, problem, Ps[v], x) for v in obs_states]

    return minimum(maximum(values) for values in vals)
end

function common(
    ::Type{<:AbstractTemplate},
    graph::_HS.GraphAutomaton,
    problem::AbstractProblem,
    Vs,
    x::AbstractVector{<:Real},
)
    return throw(ArgumentError("common currently supports only QuadraticTemplate"))
end

function _node_value end
