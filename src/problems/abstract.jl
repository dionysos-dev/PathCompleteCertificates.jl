import JuMP

"""
    AbstractProblem

Abstract supertype for the problem imposed on every edge of a path-complete
certificate.  A problem determines the edge inequality; templates determine
the family from which node functions are drawn.
"""
abstract type AbstractProblem end

"""
    add_edge_constraint!(model, problem, template, V_src, V_dst, dynamics, mode)

Add the certificate inequality for one labelled graph edge.  Each concrete
problem defines methods for the templates it supports.
"""
function add_edge_constraint! end

"""
    _n_modes(problem)

The size of the system's alphabet, whatever shape `mode_matrices` returns for
it. Needed because the question "is this graph complete?" is only meaningful
against the system's modes, not against the labels the graph happens to carry.
"""
_n_modes(problem::AbstractProblem) = _n_modes(mode_matrices(problem.system))
_n_modes(A::AbstractVector) = length(A)
_n_modes(AB::Tuple) = length(first(AB))

"""
    _node_value(template, problem, V, x)

Evaluate one node function at `x`.

Declared on the problem axis because it is one of the two methods that vary
with the (template, problem) pair: the value is the template's, but a problem
may lift it into other coordinates — `SafetyProblem` evaluates its barriers in
homogeneous coordinates, which is the one case where the pair really matters.
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
