import JuMP

"""
    AbstractProblem

A property to certify, defined by the inequality imposed along each edge.
"""
abstract type AbstractProblem end

"""
    add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; scale = 1)

Add the problem's inequality for one edge, where `dynamics` is the product of
the matrices of the modes the edge reads and `scale` multiplies the source side.
"""
function add_edge_constraint! end

# The system's modes, not the labels the graph happens to use.
_n_modes(problem::AbstractProblem) = length(mode_matrices(problem.system))

# Whether the problem accepts words on the edges; only stability does.
_accepts_words(::AbstractProblem) = false

"""
    node_value(template, problem, V, x)

Evaluate the node function `V` at `x`: `V(x)`, or `V([x; 1])` for
`SafetyProblem`.
"""
node_value(::AbstractTemplate, ::AbstractProblem, V, x::AbstractVector{<:Real}) = V(x)

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
    return _common(graph, 1:_n_modes(problem), values)
end

# Validate the modes against the graph and return the state dimension.
# `path_complete = false` skips the path-completeness test, which is expensive.
function _check_modes(
    graph::CertificateGraph,
    system::_HS.HybridSystem;
    path_complete::Bool = true,
)
    A = mode_matrices(system)

    isempty(A) && throw(ArgumentError("at least one mode is required"))

    dimension = size(first(A), 1)

    dimension > 0 || throw(ArgumentError("mode matrices must have positive dimension"))

    for (mode, A_mode) in enumerate(A)
        size(A_mode) == (dimension, dimension) || throw(
            ArgumentError(
                "A[$mode] has size $(size(A_mode)); expected ($dimension, $dimension)",
            ),
        )
    end

    for edge in edges(graph), mode in letters(label(graph, edge))
        1 <= mode <= length(A) ||
            throw(ArgumentError("edge label $mode does not index a mode in A"))
    end

    if path_complete && !is_path_complete(graph, 1:n_modes(system))
        throw(
            ArgumentError(
                "the graph is not path-complete for the system's modes, " *
                "so its edge inequalities would certify the property for part of it " *
                "only; the graph reads the modes $(sort(alphabet(graph)))",
            ),
        )
    end

    return dimension
end

# Termination statuses counted as a solution.
const _FEASIBLE_TERMINATION_STATUSES = (
    JuMP.MOI.OPTIMAL,
    JuMP.MOI.LOCALLY_SOLVED,
    JuMP.MOI.ALMOST_OPTIMAL,
    JuMP.MOI.ALMOST_LOCALLY_SOLVED,
)

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
    dual(problem)
    dual(certificate)

The problem on the dual system, and the certificate on the dual graph made of
the dual norms of the node functions. Throws for every problem but stability.
"""
dual(problem::AbstractProblem) =
    throw(ArgumentError("no dual is defined for $(nameof(typeof(problem)))"))

dual(certificate::AbstractCertificate) =
    throw(ArgumentError("no dual is defined for $(nameof(typeof(certificate)))"))

"""
    optimization_model(template, graph, problem; optimizer, kwargs...)

Build, without solving, the JuMP model that [`certify`](@ref) solves.
"""
function optimization_model end

"""
    certify(template, graph, problem; optimizer, kwargs...)

Build and solve the model, and return an [`AbstractCertificate`](@ref). Check
[`is_feasible`](@ref) before reading it.
"""
function certify end

# The CertificateData of a failed solve.
function _failed(problem::AbstractProblem, template::AbstractTemplate, graph, status)
    return CertificateData(problem, template, graph, Any[], status, false)
end

"""
    best_certificate(template, graph, problem; optimizer, kwargs...)

The certificate [`refine`](@ref) solves on each graph: that of
[`certify`](@ref), or for stability that of smallest rate, from
[`jsr_bound`](@ref).
"""
function best_certificate(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::AbstractProblem;
    optimizer,
    rtol = nothing,
    kwargs...,
)
    return certify(template, graph, problem; optimizer, kwargs...)
end

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

# The edges whose inequality is active, as transitions of the graph.
function _tight_transitions(certificate::AbstractCertificate; atol::Real)
    graph_ = graph(certificate)
    slacks = edge_slacks(certificate)

    return [edge for (edge, slack) in zip(edges(graph_), slacks) if slack <= atol]
end

"""
    tight_edges(certificate; atol = 1e-6)

The edges whose slack is at most `atol`, as `(source, destination, label)`
tuples. `atol` is absolute, so its meaning depends on the scale of the
certificate.
"""
function tight_edges(certificate::AbstractCertificate; atol::Real = 1e-6)
    graph_ = graph(certificate)

    return [
        (source(edge), dest(edge), label(graph_, edge)) for
        edge in _tight_transitions(certificate; atol = atol)
    ]
end

"""
    tight_subgraph(certificate; atol = 1e-6)

The subgraph, on the same nodes, of the edges whose slack is at most `atol`.
"""
function tight_subgraph(certificate::AbstractCertificate; atol::Real = 1e-6)
    graph_ = graph(certificate)
    subgraph = _empty_like(graph_, n_nodes(graph_))

    for edge in _tight_transitions(certificate; atol = atol)
        add_edge!(subgraph, source(edge), dest(edge), label(graph_, edge))
    end

    return subgraph
end
