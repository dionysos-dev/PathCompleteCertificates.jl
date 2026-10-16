"""
    AbstractProblem

A property to certify, defined by the inequality imposed along each edge.
"""
abstract type AbstractProblem end

# Whether the problem accepts words on the edges; only stability does.
_accepts_words(::AbstractProblem) = false

# Whether `refine` runs on the problem: its certificate has an `objective` and
# `edge_slacks`.
_refinable(::AbstractProblem) = false

"""
    node_value(template, problem, V, x)

Evaluate the node function `V` at `x`: `V(x)`, or `V([x; 1])` for
`SafetyProblem`.
"""
node_value(::AbstractTemplate, ::AbstractProblem, V, x::AbstractVector{<:Real}) = V(x)

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

The certificate [`refine`](@ref) solves on each graph: for stability that of
smallest rate, from [`jsr_bound`](@ref) to relative tolerance `rtol`; for a
problem certified by one solve, that of [`certify`](@ref), and `rtol` is
ignored.
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
    dual(problem)

The problem on the dual system. Throws for every problem but stability.
"""
dual(problem::AbstractProblem) =
    throw(ArgumentError("no dual is defined for $(nameof(typeof(problem)))"))

# Validate the modes against the graph and return the state dimension; the
# matrices themselves were checked when the problem was built.
# `check_path_complete = false` skips the path-completeness test, which is expensive.
function _check_modes(
    graph::CertificateGraph,
    system::_HS.HybridSystem;
    check_path_complete::Bool = true,
)
    A = state_matrices(system)

    for edge in edges(graph), mode in letters(label(graph, edge))
        1 <= mode <= length(A) ||
            throw(ArgumentError("edge label $mode does not index a mode in A"))
    end

    if check_path_complete && !is_path_complete(graph, 1:length(A))
        throw(
            ArgumentError(
                "the graph is not path-complete for the system's modes, " *
                "so its edge inequalities would certify the property for part of it " *
                "only; the graph reads the modes $(alphabet(graph))",
            ),
        )
    end

    return size(first(A), 1)
end
