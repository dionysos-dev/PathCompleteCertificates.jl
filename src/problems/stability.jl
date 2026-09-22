
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

"""
    StabilityCertificate

A path-complete Lyapunov function and the contraction rate it certifies.

`rate` is an **upper** bound on the joint spectral radius: every switching
sequence contracts at least this fast under the node functions. It is the
smallest rate the bisection in [`jsr_bound`](@ref) could certify with this
template on this graph, so a larger value says the template is conservative,
not that the system is slower.

`functions(certificate)` are the node Lyapunov functions and `certificate(x)`
the common one.
"""
struct StabilityCertificate{D <: CertificateData, T <: Real} <: AbstractCertificate
    data::D
    rate::T
end

# One method, generic over templates. `rate` is gamma^rate_exponent(template),
# and the whole edge condition of this problem is the template's domination
# primitive with that scale -- so a new template needs nothing here.
function add_edge_constraint!(
    model::JuMP.Model,
    problem::StabilityProblem,
    template::AbstractTemplate,
    V_src,
    V_dst,
    A::AbstractMatrix;
    rate::Real = 1,
)
    add_domination!(model, template, V_src, V_dst, A; scale = rate)

    return nothing
end

"""
    optimization_model(template, graph, problem, gamma; optimizer)

Create the feasibility problem for the Lyapunov inequalities

    V_b(A_i x) <= gamma^2 * V_a(x)

for every edge `(a, b, i)` of `graph`.

The returned model has no objective. Use [`is_stable`](@ref) or
[`jsr_bound`](@ref) to solve it.

`LinearCopositiveTemplate` requires entrywise nonnegative matrices.
`optimizer` must be an LP solver for that template and an SDP-capable
solver for `QuadraticTemplate`.
"""
function optimization_model(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem,
    gamma::Real;
    optimizer,
    path_complete::Bool = true,
)
    gamma >= 0 || throw(ArgumentError("gamma must be nonnegative"))

    A = mode_matrices(problem.system)

    _check_stability_data(template, graph, A; path_complete = path_complete)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    dimension = size(first(A), 1)

    Vs = [add_function_variables!(model, template, dimension, a) for a in nodes(graph)]

    for V in Vs
        add_nonnegativity!(model, template, V)
        add_normalization!(model, template, V)
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
            A[label(graph, edge)];
            rate = rate,
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
    path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem,
        gamma;
        optimizer,
        path_complete = path_complete,
    )

    JuMP.optimize!(model)

    return JuMP.termination_status(model) in _FEASIBLE_TERMINATION_STATUSES
end

"""
    jsr_bound(template, graph, problem; optimizer, rtol = 1e-3,
              max_iterations = 100, initial_upper = 1.0)

Estimate an upper bound on the joint spectral radius by bisection.

At each candidate `gamma`, solve the fixed-`gamma` feasibility problem
over every edge `(a, b, i)`.

Returns a [`StabilityCertificate`](@ref). Its `rate` is the smallest feasible
bound found to relative tolerance `rtol`; `functions(certificate)` are the
node Lyapunov functions, and `certificate(x)` evaluates the common one.
"""
function jsr_bound(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    rtol::Real = 1e-3,
    max_iterations::Integer = 100,
    initial_upper::Real = 1.0,
    path_complete::Bool = true,
)
    rtol > 0 || throw(ArgumentError("rtol must be positive"))

    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive"))

    initial_upper > 0 || throw(ArgumentError("initial_upper must be positive"))

    A = mode_matrices(problem.system)

    # Once, here. The bisection below builds a model per step and each build
    # revalidates, so leaving this on would run a PSPACE-complete test a dozen
    # times over on a graph that cannot have changed.
    _check_stability_data(template, graph, A; path_complete = path_complete)

    lower = zero(initial_upper)
    upper = initial_upper

    while !is_stable(template, graph, problem, upper; optimizer, path_complete = false)
        upper *= 2

        isfinite(upper) ||
            throw(ArgumentError("could not find a finite feasible upper bound"))
    end

    for _ in 1:max_iterations
        upper - lower <= rtol * upper && break

        candidate = (lower + upper) / 2

        if is_stable(template, graph, problem, candidate; optimizer, path_complete = false)
            upper = candidate
        else
            lower = candidate
        end
    end

    certificate = certify(
        template,
        graph,
        problem;
        optimizer = optimizer,
        rate = upper,
        path_complete = false,
    )

    is_feasible(certificate) ||
        throw(ArgumentError("the final stability problem is not feasible"))

    return certificate
end

"""
    certify(template, graph, problem::StabilityProblem; optimizer, rate = 1)

Solve the fixed-`rate` Lyapunov feasibility problem once.

This is the single solve; [`jsr_bound`](@ref) bisects on `rate` on top of it,
and [`is_stable`](@ref) asks only whether a given rate is feasible.
"""
function certify(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::StabilityProblem;
    optimizer,
    rate::Real = 1,
    path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem,
        rate;
        optimizer = optimizer,
        path_complete = path_complete,
    )

    JuMP.optimize!(model)
    status = JuMP.termination_status(model)

    status in _FEASIBLE_TERMINATION_STATUSES ||
        return StabilityCertificate(_failed(problem, template, graph, status), rate)

    V = [solution_value(template, v) for v in model[:stability_V]]

    return StabilityCertificate(
        CertificateData(problem, template, graph, V, status, true),
        rate,
    )
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

function _check_stability_data(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    A::AbstractVector{<:AbstractMatrix};
    path_complete::Bool = true,
)
    _check_modes(graph, A; path_complete = path_complete)
    check_dynamics(template, A)

    return nothing
end
