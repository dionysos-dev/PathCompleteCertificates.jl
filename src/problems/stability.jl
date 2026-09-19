
"""
    StabilityProblem(system)

Stability problem for an input-free switched linear system.

The problem stores the system only. The decay rate `gamma` is specified
when constructing the feasibility model.
"""
struct StabilityProblem{S} <: AbstractProblem
    system::S

    function StabilityProblem(system::S) where {S}
        # Without this, `mode_matrices` returns the (A, B) pair and the failure
        # surfaces much later as a MethodError inside the model builder.
        has_input(system) &&
            throw(ArgumentError("StabilityProblem requires an input-free system"))

        return new{typeof(system)}(system)
    end
end

function _node_value(
    ::QuadraticTemplate,
    ::StabilityProblem,
    P::AbstractMatrix,
    x::AbstractVector{<:Real},
)
    return LinearAlgebra.dot(x, P * x)
end

function _node_value(
    ::PolyhedralTemplate,
    ::StabilityProblem,
    V::PolyhedralFunction,
    x::AbstractVector{<:Real},
)
    return V(x)
end

# `rate` is gamma^rate_exponent(template) -- see `rate_exponent`. Each method
# below states the edge condition against it, so none of them hard-codes the
# template's degree.
function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    ::LinearCopositiveTemplate,
    c_src,
    c_dst,
    A::AbstractMatrix,
    rate::Real,
)
    JuMP.@constraint(model, transpose(A) * c_dst .<= rate * c_src)

    return nothing
end

function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    ::QuadraticTemplate,
    P_src::LinearAlgebra.Symmetric,
    P_dst::LinearAlgebra.Symmetric,
    A::AbstractMatrix,
    rate::Real,
)
    JuMP.@constraint(model, rate * P_src - transpose(A) * P_dst * A in JuMP.PSDCone())

    return nothing
end

function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    ::PolyhedralTemplate,
    V_src::PolyhedralFunction,
    V_dst::PolyhedralFunction,
    A::AbstractMatrix,
    rate::Real,
)
    # V_dst(Ax) <= rate * V_src(x) for every x is, after the change of
    # coordinates z = W_src^-1 G_src x, the statement that the infinity-norm
    # induced norm of W_dst^-1 G_dst A G_src^-1 W_src is at most `rate`. Row by
    # row that is |G_dst A G_src^-1| w_src <= rate * w_dst -- linear in w, which
    # is what keeps this template an LP.
    #
    # Note the weights of the *destination* carry the rate: w sits in a
    # denominator, so it runs opposite to P and c.
    M = abs.(V_dst.G * A * inv(V_src.G))

    JuMP.@constraint(model, M * V_src.w .<= rate * V_dst.w)

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
    template::AbstractTemplate,
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
        add_nonnegativity!(model, template, V)
        _add_normalization!(model, template, V)
    end

    # The template's degree of homogeneity, not a hard-coded square: `gamma` is
    # the contraction rate for every template, so `jsr_bound` means the same
    # thing whichever one is in use.
    rate = gamma^rate_exponent(template)

    for edge in edges(graph)
        add_edge_constraint!(
            model,
            problem,
            template,
            Vs[source(edge)],
            Vs[dest(edge)],
            A[label(graph, edge)],
            rate,
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
    template::AbstractTemplate,
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
    template::AbstractTemplate,
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

    V = [solution_value(template, v) for v in model[:stability_V]]

    return (bound = upper, V = V, feasible = true)
end

"""
    jsr_bound(template, graph, system; kwargs...)

Estimate a joint-spectral-radius bound for an input-free switched system.
"""
function jsr_bound(
    template::AbstractTemplate,
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

function _add_normalization!(model::JuMP.Model, ::LinearCopositiveTemplate, c)
    JuMP.@constraint(model, c .>= 1)

    return nothing
end

function _add_normalization!(model::JuMP.Model, ::QuadraticTemplate, P)
    JuMP.@constraint(model, P - LinearAlgebra.I in JuMP.PSDCone(),)
    JuMP.@constraint(model, 100*LinearAlgebra.I - P in JuMP.PSDCone(),)

    return nothing
end

function _add_normalization!(model::JuMP.Model, ::PolyhedralTemplate, ::PolyhedralFunction)
    # `add_nonnegativity!` already floors the weights at `min_weight`, which is
    # both the positivity and the normalization here: the edge conditions are
    # homogeneous in w, so scaling every weight by t > 0 changes nothing.
    return nothing
end

function _check_stability_data(
    template::AbstractTemplate,
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

    if template isa LinearCopositiveTemplate && any(A_i -> any(<(0), A_i), A)
        throw(
            ArgumentError(
                "LinearCopositiveTemplate requires entrywise nonnegative matrices",
            ),
        )
    end

    _check_path_complete(graph, length(A))

    return nothing
end
