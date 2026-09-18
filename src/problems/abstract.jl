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
