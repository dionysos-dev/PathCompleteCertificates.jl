
"""
    StabilityProblem(system)

Stability problem for an input-free switched linear system.

The problem stores the system only. The decay rate `gamma` is specified
when constructing the feasibility model.
"""
struct StabilityProblem{S} <: AbstractProblem
    system::S

    function StabilityProblem(system::S) where {S}
        has_input(system) &&
            throw(ArgumentError("StabilityProblem requires an input-free system"))

        return new{S}(system)
    end
end

function _node_value(
    ::Type{QuadraticTemplate},
    ::StabilityProblem,
    P::AbstractMatrix,
    x::AbstractVector{<:Real},
)
    return LinearAlgebra.dot(x, P * x)
end

function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    ::Type{LinearCopositiveTemplate},
    c_src,
    c_dst,
    A::AbstractMatrix,
    gamma::Real,
)
    JuMP.@constraint(model, transpose(A) * c_dst .<= gamma^2 * c_src,)

    return nothing
end

function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    ::Type{QuadraticTemplate},
    P_src::LinearAlgebra.Symmetric,
    P_dst::LinearAlgebra.Symmetric,
    A::AbstractMatrix,
    gamma::Real,
)
    JuMP.@constraint(model, gamma^2 * P_src - transpose(A) * P_dst * A in JuMP.PSDCone(),)

    return nothing
end

"""
    stability_problem(template, graph, problem, gamma; optimizer)

Create the feasibility problem for the Lyapunov inequalities

    V_b(A_i x) <= gamma^2 * V_a(x)

for every edge `(a, b, i)` of `graph`.

The returned model has no objective. Use [`is_stable`](@ref) or
[`jsr_bound`](@ref) to solve it.

`LinearCopositiveTemplate` requires entrywise nonnegative matrices.
`optimizer` must be an LP solver for that template and an SDP-capable
solver for `QuadraticTemplate`.
"""
function stability_problem(
    template::Type{<:AbstractTemplate},
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem,
    gamma::Real;
    optimizer,
)
    gamma >= 0 || throw(ArgumentError("gamma must be nonnegative"))

    A = mode_matrices(problem.system)

    _check_stability_data(template, graph, A)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    dimension = size(first(A), 1)

    Vs = [add_function_variables!(model, template, dimension, a) for a in nodes(graph)]

    for V in Vs
        add_nonnegativity!(model, V)
        _add_normalization!(model, template, V)
    end

    for edge in edges(graph)
        add_edge_constraint!(
            model,
            problem,
            template,
            Vs[source(edge)],
            Vs[dest(edge)],
            A[label(graph, edge)],
            gamma,
        )
    end

    model[:stability_V] = Vs

    return model
end

"""
    is_stable(template, graph, problem, gamma; optimizer) -> Bool

Return whether the fixed-`gamma` Lyapunov feasibility problem is solved
to a feasible termination status.
"""
function is_stable(
    template::Type{<:AbstractTemplate},
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem,
    gamma::Real;
    optimizer,
)
    model = stability_problem(template, graph, problem, gamma; optimizer)

    JuMP.optimize!(model)

    return JuMP.termination_status(model) in _FEASIBLE_TERMINATION_STATUSES
end

"""
    jsr_bound(template, graph, problem; optimizer, rtol = 1e-3,
              max_iterations = 100, initial_upper = 1.0)

Estimate an upper bound on the joint spectral radius by bisection.

At each candidate `gamma`, solve the fixed-`gamma` feasibility problem
over every edge `(a, b, i)`.

The result is a named tuple containing the smallest feasible bound found to
relative tolerance `rtol` and the corresponding node functions.
"""
function jsr_bound(
    template::Type{<:AbstractTemplate},
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    rtol::Real = 1e-3,
    max_iterations::Integer = 100,
    initial_upper::Real = 1.0,
)
    rtol > 0 || throw(ArgumentError("rtol must be positive"))

    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive"))

    initial_upper > 0 || throw(ArgumentError("initial_upper must be positive"))

    A = mode_matrices(problem.system)
    _check_stability_data(template, graph, A)

    lower = zero(initial_upper)
    upper = initial_upper

    while !is_stable(template, graph, problem, upper; optimizer)
        upper *= 2

        isfinite(upper) ||
            throw(ArgumentError("could not find a finite feasible upper bound"))
    end

    for _ in 1:max_iterations
        upper - lower <= rtol * upper && break

        candidate = (lower + upper) / 2

        if is_stable(template, graph, problem, candidate; optimizer)
            upper = candidate
        else
            lower = candidate
        end
    end

    model = stability_problem(template, graph, problem, upper; optimizer)
    JuMP.optimize!(model)

    status = JuMP.termination_status(model)
    status in _FEASIBLE_TERMINATION_STATUSES ||
        throw(ArgumentError("the final stability problem is not feasible"))

    V = [JuMP.value.(v) for v in model[:stability_V]]

    return (bound = upper, V = V, feasible = true)
end

"""
    jsr_bound(template, graph, system; kwargs...)

Estimate a joint-spectral-radius bound for an input-free switched system.
"""
function jsr_bound(
    template::Type{<:AbstractTemplate},
    graph::_HS.GraphAutomaton,
    system::_HS.HybridSystem;
    kwargs...,
)
    problem = StabilityProblem(system)

    return jsr_bound(template, graph, problem; kwargs...)
end

const _FEASIBLE_TERMINATION_STATUSES = (
    JuMP.MOI.OPTIMAL,
    JuMP.MOI.LOCALLY_SOLVED,
    JuMP.MOI.ALMOST_OPTIMAL,
    JuMP.MOI.ALMOST_LOCALLY_SOLVED,
)

function _add_normalization!(model::JuMP.Model, ::Type{LinearCopositiveTemplate}, c)
    JuMP.@constraint(model, c .>= 1)

    return nothing
end

function _add_normalization!(model::JuMP.Model, ::Type{QuadraticTemplate}, P)
    JuMP.@constraint(model, P - LinearAlgebra.I in JuMP.PSDCone(),)
    JuMP.@constraint(model, 100*LinearAlgebra.I - P in JuMP.PSDCone(),)

    return nothing
end

function _check_stability_data(
    template::Type{<:AbstractTemplate},
    graph::_HS.GraphAutomaton,
    A::AbstractVector{<:AbstractMatrix},
)
    isempty(A) && throw(ArgumentError("at least one mode is required"))

    dimension = size(first(A), 1)

    dimension > 0 || throw(ArgumentError("mode matrices must have positive dimension"))

    for (i, A_i) in enumerate(A)
        size(A_i) == (dimension, dimension) || throw(
            ArgumentError(
                "A[$i] has size $(size(A_i)); " * "expected ($dimension, $dimension)",
            ),
        )
    end

    for edge in edges(graph)
        edge_label = label(graph, edge)
        1 <= edge_label <= length(A) ||
            throw(ArgumentError("edge label $edge_label does not index a mode in A"))
    end

    if template === LinearCopositiveTemplate && any(A_i -> any(<(0), A_i), A)
        throw(
            ArgumentError(
                "LinearCopositiveTemplate requires entrywise nonnegative matrices",
            ),
        )
    end

    return nothing
end
