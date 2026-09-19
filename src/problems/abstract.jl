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
"""
function _check_modes(graph::_HS.GraphAutomaton, A::AbstractVector{<:AbstractMatrix})
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

    _check_path_complete(graph, length(A))

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
