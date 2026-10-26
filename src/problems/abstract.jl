"""
    AbstractProblem

A property to certify, defined by the inequality imposed along each edge.
"""
abstract type AbstractProblem end

# Whether `refine` runs on the problem: its certificate type has methods for
# `objective` and `edge_slacks`.
_refinable(::AbstractProblem) = false

"""
    node_value(problem, V, x)

The value of the node function `V` at the state `x`: `V(x)` by default. A
problem whose node functions take other coordinates than `x` defines its own
method, e.g. `V([x; 1])` for [`SafetyProblem`](@ref), in homogeneous
coordinates.
"""
node_value(::AbstractProblem, V, x::AbstractVector{<:Real}) = V(x)

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

"""
    best_certificate(template, graph, problem; optimizer, rtol, kwargs...)

The certificate of best [`objective`](@ref) on `graph`. [`refine`](@ref)
calls it on every graph it visits.

It differs from [`certify`](@ref) only when `certify` fixes the objective
instead of optimizing it. Stability is that case: `certify` checks one given
rate, and `best_certificate` bisects for the smallest, to relative tolerance
`rtol`.
"""
function best_certificate(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::AbstractProblem;
    optimizer,
    rtol = nothing,
    kwargs...,
)
    return certify(template, graph, problem; optimizer, kwargs...)
end

"""
    dual(problem)

The dual of `problem`. Throws for a problem that defines no dual.
"""
dual(problem::AbstractProblem) =
    throw(ArgumentError("no dual is defined for $(nameof(typeof(problem)))"))

# Check that `graph` can certify `system`: its edges read modes of the system,
# and it is path-complete for them, which `check_path_complete = false` skips.
function _check_graph_suitability(
    graph::CertificateGraph,
    system::_HS.HybridSystem;
    check_path_complete::Bool = true,
)
    modes = n_modes(system)

    for edge in edges(graph), mode in letters(label(graph, edge))
        1 <= mode <= modes || throw(
            ArgumentError("an edge reads mode $mode, but the system has modes 1:$modes"),
        )
    end

    if check_path_complete && !is_path_complete(graph, 1:modes)
        throw(
            ArgumentError(
                "the graph is not path-complete for the system's modes, " *
                "so its edge inequalities would certify the property for part of it " *
                "only; the graph reads the modes $(alphabet(graph))",
            ),
        )
    end

    return nothing
end
