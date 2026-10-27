# What every certificate shares: its type, its accessors and `common`. Below
# them, `dual`, `objective`, `optimality_gap` and `edge_slacks`, which each
# problem's certificate defines in catalogue/.

"""
    AbstractCertificate

The result of [`certify`](@ref): node functions on a graph, and what the
problem certifies. A certificate `c` is callable: `c(x)` returns the value of
its [`common`](@ref) function at `x`.
"""
abstract type AbstractCertificate end

"""
    CertificateData(problem, template, graph, functions, status, feasible)

The fields shared by every certificate:
- `problem`, the problem certified;
- `template`, the template the node functions are drawn from;
- `graph`, the path-complete graph they sit on;
- `functions`, the node function at each node, empty after a failed solve;
- `status`, the solver's termination status;
- `feasible`, whether the solve produced a certificate, read by
  [`is_feasible`](@ref).
"""
struct CertificateData{P <: AbstractProblem, T <: _SetFamily, G, F, S}
    problem::P
    template::T
    graph::G
    functions::Vector{F}
    status::S
    feasible::Bool
end

# The CertificateData of a failed solve.
function _failed(problem::AbstractProblem, template::_SetFamily, graph, status)
    return CertificateData(problem, template, graph, Any[], status, false)
end

# The functions below all read `certificate.data`, the CertificateData that each
# certificate type in catalogue/ stores as its field `data`, next to the fields
# of what it certifies.
_data(certificate::AbstractCertificate) = certificate.data

"""
    functions(certificate)

The node function at each node, indexed by node; empty after a failed solve.
"""
functions(certificate::AbstractCertificate) = _data(certificate).functions

"""
    status(certificate)

The solver's termination status, for diagnosis. Read [`is_feasible`](@ref) to
know whether the certificate holds: it may accept an almost-optimal solve, or
reject a solution the solver reported optimal.
"""
status(certificate::AbstractCertificate) = _data(certificate).status

"""
    is_feasible(certificate) -> Bool

Whether the solve produced a certificate. `false` means none exists in this
template on this graph, not that the property fails.
"""
is_feasible(certificate::AbstractCertificate) = _data(certificate).feasible

"""
    problem(certificate)

The problem the certificate was produced for.
"""
problem(certificate::AbstractCertificate) = _data(certificate).problem

"""
    template(certificate)

The template its node functions are drawn from.
"""
template(certificate::AbstractCertificate) = _data(certificate).template

"""
    graph(certificate)

The path-complete graph the certificate is built on.
"""
graph(certificate::AbstractCertificate) = _data(certificate).graph

"""
    common(graph, problem, Vs, x)

The common function of the node functions `Vs` on `graph`, evaluated at `x`: a
minimum of maxima of the `Vs` [philippe2019path](@cite). Depending on `problem`,
a common Lyapunov function, a common barrier function or a bound on the value
function.
"""
function common(
    graph::CertificateGraph,
    problem::AbstractProblem,
    Vs::AbstractVector,
    x::AbstractVector{<:Real},
)
    values = [node_value(problem, V, x) for V in Vs]
    states = _common_states(graph, 1:n_modes(problem.system))
    return minimum(maximum(values[node] for node in state) for state in states)
end

"""
    (certificate::AbstractCertificate)(x)

The [`common`](@ref) function of the certificate at `x`. Throws on an
infeasible certificate.
"""
function (certificate::AbstractCertificate)(x::AbstractVector{<:Real})
    is_feasible(certificate) ||
        throw(ArgumentError("an infeasible certificate has no common function"))

    return common(graph(certificate), problem(certificate), functions(certificate), x)
end

"""
    dual(certificate)

The certificate on the dual graph made of the dual norms of the node functions.
Throws for a certificate whose problem defines no dual.
"""
dual(certificate::AbstractCertificate) =
    throw(ArgumentError("no dual is defined for $(nameof(typeof(certificate)))"))

"""
    objective(certificate) -> Real

The number [`refine`](@ref) aims to lower from one graph to the next, such as
the `rate` of a [`StabilityCertificate`](@ref).
"""
function objective end

"""
    optimality_gap(certificate; kwargs...) -> Real

An upper bound on how far [`objective`](@ref) is from the best any graph could
reach: `0` when proved optimal, `Inf` by default.
"""
optimality_gap(::AbstractCertificate; kwargs...) = Inf

"""
    edge_slacks(certificate)

The slack of every edge inequality, in `edges(graph(certificate))` order; zero
means tight. For stability, slacks are relative to the scale of the node
functions, so they do not depend on its normalization, and a tight edge has a
slack of the order of `rtol`. Throws on an infeasible certificate.
"""
function edge_slacks end

# `edge_slacks` for a problem whose edge inequality has the form
# `scale·V_src(x) ≥ V_dst(dynamics·x)`, with `(dynamics, scale)` from its
# `_edge_decrease`, given `kwargs`.
function _edge_slacks(certificate::AbstractCertificate; kwargs...)
    is_feasible(certificate) ||
        throw(ArgumentError("an infeasible certificate has no functions to measure"))

    problem_ = problem(certificate)
    graph_ = graph(certificate)
    template_ = template(certificate)
    V = functions(certificate)
    A = state_matrices(problem_.system)

    return map(edges(graph_)) do edge
        dynamics, scale = _edge_decrease(problem_, graph_, edge, A; kwargs...)
        return decrease_slack(
            template_ isa AbstractVector ? template_[source(edge)] : template_,
            V[source(edge)],
            V[dest(edge)],
            dynamics;
            scale,
        )
    end
end
