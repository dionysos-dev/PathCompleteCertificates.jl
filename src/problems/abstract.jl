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
