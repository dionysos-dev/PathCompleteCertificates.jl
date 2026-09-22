import JuMP

"""
    AbstractProblem

What is proved: a problem determines the edge inequality, templates the family
the node functions are drawn from.
"""
abstract type AbstractProblem end

"""
    add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; rate = 1)

Add this problem's certificate inequality for one labelled graph edge.

One method per problem, generic in the template: compose the template's
primitives rather than dispatching on a template here.

`rate` is the per-solve scalar a driver varies, such as the contraction rate
stability bisects on. A problem with no such scalar ignores it.
"""
function add_edge_constraint! end

"""
    _n_modes(problem)

The size of the system's alphabet — which is what completeness must be judged
against, not the labels the graph happens to carry.
"""
_n_modes(problem::AbstractProblem) = length(mode_matrices(problem.system))

"""
    node_value(template, problem, V, x)

Evaluate one node function at `x`.

On the problem axis because a problem may lift the value into other coordinates:
`SafetyProblem` evaluates its barriers at `[x; 1]`, and that is the only pair
where it matters.
"""
function node_value end

function node_value(
    template::AbstractTemplate,
    problem::AbstractProblem,
    V,
    ::AbstractVector{<:Real},
)
    return throw(
        ArgumentError(
            "no node-function evaluation for $(typeof(template)) on " *
            "$(nameof(typeof(problem))); define `node_value` for that pair",
        ),
    )
end

"""
    _check_modes(graph, A)

Validate the mode matrices against the graph, and return the state dimension.

Square matrices of one size, edge labels that index them, and a graph that is
path-complete for the system's alphabet. Anything beyond that is the problem's
own business.

`path_complete = false` waives the last test and **asserts** it instead —
deciding it is PSPACE-complete (see [`is_path_complete`](@ref)). Not the
default: what it guards against is silent.
"""
function _check_modes(
    graph::_HS.GraphAutomaton,
    A::AbstractVector{<:AbstractMatrix};
    path_complete::Bool = true,
)
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

    for edge in edges(graph)
        mode = label(graph, edge)
        1 <= mode <= length(A) ||
            throw(ArgumentError("edge label $mode does not index a mode in A"))
    end

    path_complete && _check_path_complete(graph, length(A))

    return dimension
end

"""
    _FEASIBLE_TERMINATION_STATUSES

Termination statuses a driver treats as "the solver found something".
"""
const _FEASIBLE_TERMINATION_STATUSES = (
    JuMP.MOI.OPTIMAL,
    JuMP.MOI.LOCALLY_SOLVED,
    JuMP.MOI.ALMOST_OPTIMAL,
    JuMP.MOI.ALMOST_LOCALLY_SOLVED,
)

"""
    AbstractCertificate

What a problem hands back: the fitted node functions, plus whatever that
problem certifies.

One certificate type per problem, declared in the problem's own file, with what
it certifies as typed fields. What they all share lives once in
[`CertificateData`](@ref), held in a field named `data` and read by the
accessors below.

A certificate is **callable**: `certificate(x)` is [`common`](@ref) at `x`.
"""
abstract type AbstractCertificate end

"""
    CertificateData(problem, template, graph, functions, status, feasible)

The part of a certificate that does not depend on which problem produced it,
declared once rather than repeated in each problem's type.
"""
struct CertificateData{P <: AbstractProblem, T <: AbstractTemplate, G, F, S}
    problem::P
    template::T
    graph::G
    functions::Vector{F}
    status::S
    feasible::Bool
end

"""
    _data(certificate)

The shared [`CertificateData`](@ref). Override this one method and a
certificate inherits every accessor.
"""
_data(certificate::AbstractCertificate) = certificate.data

"""
    functions(certificate)

The fitted node function at each node, indexed by node.
"""
functions(certificate::AbstractCertificate) = _data(certificate).functions

"""
    status(certificate)

The solver's termination status.

Distinct from [`is_feasible`](@ref): a solver can terminate happily on a model
whose solution fails the conditions when re-checked, and the problems re-check.
"""
status(certificate::AbstractCertificate) = _data(certificate).status

"""
    is_feasible(certificate) -> Bool

Whether the solve produced a certificate.

`false` means none was found **for this template on this graph** — never that
the property fails.
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
    optimization_model(template, graph, problem; optimizer, kwargs...)

Build the JuMP model this problem and template induce on `graph`, without
solving it.

One method per problem. Use it to inspect the program, add your own
constraints, or change the objective before handing it to `JuMP.optimize!`;
[`certify`](@ref) is this plus the solve and the extraction.

The name avoids `model`, which is the first argument of every template
primitive and would be shadowed inside each of them, and avoids `program`,
which reads a letter away from `problem`.
"""
function optimization_model end

"""
    certify(template, graph, problem; optimizer, kwargs...)

Solve for the guarantee, and return an [`AbstractCertificate`](@ref).

One entry point for every problem: build the model, solve it, and read the
result back. What each problem certifies is a typed field on the certificate it
returns — `rate`, `margin`, `gains`.

Check [`is_feasible`](@ref) before reading anything else. An infeasible result
is still a certificate object, carrying the solver [`status`](@ref) so that "no
certificate exists in this template on this graph" is distinguishable from "the
solver gave up".

Not to be confused with refutation, when that lands: sampling for a violation
is a cheap way to learn you are wrong, and finding none proves nothing.
"""
function certify end

"""
    _failed(problem, template, graph, status)

The [`CertificateData`](@ref) of a solve that produced nothing.

`functions` is empty, and its element type is deliberately unconstrained: there
is no fitted function to name a type after, and naming one anyway is how this
came to claim `QuadraticFunction` for templates that are nothing of the kind.
"""
function _failed(problem::AbstractProblem, template::AbstractTemplate, graph, status)
    return CertificateData(problem, template, graph, Any[], status, false)
end
