"""
    AbstractCertificate

The result of [`certify`](@ref): node functions on a graph, and the value
certified (`rate`, `margin` or `gains`). A certificate `c` is callable: `c(x)`
is [`common`](@ref)`(template(c), graph(c), problem(c), functions(c), x)`.
"""
abstract type AbstractCertificate end

"""
    CertificateData(problem, template, graph, functions, status, feasible)

The fields shared by every certificate.
"""
struct CertificateData{P <: AbstractProblem, T <: AbstractTemplate, G, F, S}
    problem::P
    template::T
    graph::G
    functions::Vector{F}
    status::S
    feasible::Bool
end

# The CertificateData of a failed solve.
function _failed(problem::AbstractProblem, template::AbstractTemplate, graph, status)
    return CertificateData(problem, template, graph, Any[], status, false)
end

# A certificate storing its CertificateData in a field `data` gets every accessor.
_data(certificate::AbstractCertificate) = certificate.data

"""
    functions(certificate)

The fitted node function at each node, indexed by node.
"""
functions(certificate::AbstractCertificate) = _data(certificate).functions

"""
    status(certificate)

The solver's termination status, which may disagree with [`is_feasible`](@ref).
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
    common(template, graph, problem, Vs, x)

The common function of the node functions `Vs` on `graph`, evaluated at `x`: a
minimum of maxima of the `Vs` [philippe2017path](@cite). Depending on `problem`,
a common Lyapunov function, a common barrier function or a bound on the value
function.
"""
function common(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::AbstractProblem,
    Vs::AbstractVector,
    x::AbstractVector{<:Real},
)
    values = [node_value(template, problem, V, x) for V in Vs]
    return _common(graph, 1:n_modes(problem.system), values)
end

function (certificate::AbstractCertificate)(x::AbstractVector{<:Real})
    return common(
        template(certificate),
        graph(certificate),
        problem(certificate),
        functions(certificate),
        x,
    )
end

"""
    dual(certificate)

The certificate on the dual graph made of the dual norms of the node functions.
Throws for every problem but stability.
"""
dual(certificate::AbstractCertificate) =
    throw(ArgumentError("no dual is defined for $(nameof(typeof(certificate)))"))

"""
    objective(certificate) -> Real

The value [`refine`](@ref) minimises: the rate for stability, minus the margin
for safety.
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
means tight. Throws on an infeasible certificate.
"""
function edge_slacks end
