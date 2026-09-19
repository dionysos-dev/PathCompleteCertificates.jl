import JuMP

"""
    AbstractProblem

Abstract supertype for the problem imposed on every edge of a path-complete
certificate.  A problem determines the edge inequality; templates determine
the family from which node functions are drawn.
"""
abstract type AbstractProblem end

"""
    add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics; rate = 1)

Add this problem's certificate inequality for one labelled graph edge.

**One method per problem, generic in the template.** Compose the template's
primitives — chiefly [`add_domination!`](@ref) — rather than dispatching on a
template here; a method indexed by a (problem, template) pair is the thing this
interface exists to avoid, and the only one left is optimal control's, which
cannot be written in the primal variables at all.

`rate` is the per-solve scalar a driver varies, such as the contraction rate
stability bisects on. A problem with no such scalar ignores it.
"""
function add_edge_constraint! end

"""
    _n_modes(problem)

The size of the system's alphabet.

Needed because "is this graph complete?" is only meaningful against the system's
modes, not against the labels the graph happens to carry.
"""
_n_modes(problem::AbstractProblem) = length(mode_matrices(problem.system))

"""
    node_value(template, problem, V, x)

Evaluate one node function at `x`.

Declared on the problem axis because it is one of the two methods that vary
with the (template, problem) pair: the value is the template's, but a problem
may lift it into other coordinates — `SafetyProblem` evaluates its barriers in
homogeneous coordinates, which is the one case where the pair really matters.
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

Every problem needs exactly this — square matrices of one size, edge labels that
index them, and a graph that is path-complete for the system's alphabet — so it
is written once. Anything beyond it is the problem's own business and stays in
the problem's file.

`path_complete = false` skips the path-completeness test and **asserts** it
instead. Deciding it is PSPACE-complete (see `is_path_complete`), so a caller
with a large or adversarial graph, or one whose construction already guarantees
the property, needs a way out. It is not the default: the failure it guards
against is silent, and a rare performance cliff is the better risk.
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

Shared by every problem, so it lives here: it was previously defined in
`stability.jl` and used from `safety.jl`, which made one problem file depend on
another for no reason.
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
particular problem certifies.

**One certificate type per problem, defined in the problem's own file.** A
stability certificate carries a contraction rate, a safety certificate a
separation margin and its S-procedure multipliers, an optimal-control
certificate its feedback gains — as typed fields, not as entries in an untyped
bag. Adding a problem means adding its certificate beside it, and nothing here
changes.

What every certificate shares — the problem, the template, the graph, the node
functions, the solver status — lives once in [`CertificateData`](@ref), which
each concrete type holds in a field named `data`. The accessors below read it,
so subtypes implement nothing unless they store it differently.

A certificate is **callable**: `certificate(x)` is [`common`](@ref) evaluated at
`x` — the Lyapunov function, barrier or value-function bound the graph and
templates induce. That is usually what you want rather than the node functions
one at a time.
"""
abstract type AbstractCertificate end

"""
    CertificateData(problem, template, graph, functions, status, feasible)

The part of a certificate that does not depend on which problem produced it.

Held in the `data` field of every [`AbstractCertificate`](@ref) so that the six
shared fields are declared once rather than repeated in each problem's type.
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

The shared [`CertificateData`](@ref). The default reads the `data` field; a
certificate that stores it elsewhere overrides this one method and inherits
every accessor.
"""
_data(certificate::AbstractCertificate) = certificate.data

"""
    functions(certificate)

The fitted node function at each node, indexed by node.
"""
functions(certificate::AbstractCertificate) = _data(certificate).functions

"""
    status(certificate)

The solver's termination status, unchanged.

Kept distinct from [`is_feasible`](@ref): a solver can terminate happily on a
model whose solution does not satisfy the conditions when they are re-checked,
and the problems do re-check.
"""
status(certificate::AbstractCertificate) = _data(certificate).status

"""
    is_feasible(certificate) -> Bool

Whether the solve produced a certificate.

`false` means none was found **for this template on this graph** — never that
the property fails. A richer template or a finer graph may well succeed where
this one did not, which is the whole point of having more than one.
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
