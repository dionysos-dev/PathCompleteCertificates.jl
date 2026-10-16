"""
    SafetyProblem(system, S0, Su)

Safety problem for an input-free switched linear system [anand2024barrier](@cite),
with initial and unsafe sets `{x : [x; 1]' S [x; 1] ≥ 0}` for `S = S0, Su`.
The barrier at node `v` is `[x; 1]' P_v [x; 1]` with `P_v` symmetric, not
necessarily positive semidefinite.
"""
struct SafetyProblem{S, M0 <: AbstractMatrix, Mu <: AbstractMatrix} <: AbstractProblem
    system::S
    S0::M0
    Su::Mu

    function SafetyProblem(system::S, S0::AbstractMatrix, Su::AbstractMatrix) where {S}
        has_input(system) &&
            throw(ArgumentError("SafetyProblem requires an input-free system"))

        n = _check_state_matrices(state_matrices(system))
        d = n + 1

        size(S0) == (d, d) ||
            throw(ArgumentError("S0 has size $(size(S0)); expected ($d, $d)"))

        size(Su) == (d, d) ||
            throw(ArgumentError("Su has size $(size(Su)); expected ($d, $d)"))

        isapprox(S0, transpose(S0)) || throw(ArgumentError("S0 must be symmetric"))

        isapprox(Su, transpose(Su)) || throw(ArgumentError("Su must be symmetric"))

        return new{typeof(system), typeof(S0), typeof(Su)}(system, S0, Su)
    end
end

"""
    SafetyCertificate

A path-complete barrier function, its `margin` of separation between the
initial and unsafe sets (positive when safety is certified), and the S-procedure
multipliers `initial_multipliers` and `unsafe_multipliers`, one per node.
"""
struct SafetyCertificate{D <: CertificateData, T, M} <: AbstractCertificate
    data::D
    margin::T
    initial_multipliers::M
    unsafe_multipliers::M
end

# The decrease condition of `edge`, `B_dst(A x) <= B_src(x)` in homogeneous
# coordinates: the barrier need only not increase, so the scale is 1 and the
# rate and degree the slacks pass are ignored. Written once, for the model and
# for the slacks.
_edge_decrease(::SafetyProblem, graph::CertificateGraph, edge, A; kwargs...) =
    (_homogeneous_dynamics(A[only(letters(label(graph, edge)))]), 1)

# The matrices the S-procedure keeps above `margin * I` at each node, so that
# the barrier is negative on the initial set and positive on the unsafe set.
# Written once, for the model and for the check of its solution.
_initial_separation(problem::SafetyProblem, P, γ) = -(P + γ * problem.S0)
_unsafe_separation(problem::SafetyProblem, P, γ) = P - γ * problem.Su

"""
    optimization_model(template, graph, problem; optimizer)

Build, without solving, the barrier program; only `QuadraticTemplate` is supported.
"""
function optimization_model(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::SafetyProblem;
    optimizer,
    check_path_complete::Bool = true,
)
    template isa QuadraticTemplate ||
        throw(ArgumentError("SafetyProblem currently supports only QuadraticTemplate"))

    n = _check_safety_data(graph, problem; check_path_complete = check_path_complete)
    A = state_matrices(problem.system)
    d = n + 1

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    # No PSD constraint on the barriers: it would force P = 0.
    Ps = [add_function_variables!(model, template, d, i) for i in nodes(graph)]

    gamma0 = [
        JuMP.@variable(model, lower_bound = 0, base_name = "gamma0_$i") for
        i in nodes(graph)
    ]

    gammau = [
        JuMP.@variable(model, lower_bound = 0, base_name = "gammau_$i") for
        i in nodes(graph)
    ]

    eps = JuMP.@variable(model, lower_bound = 0, base_name = "eps")

    for i in nodes(graph)
        JuMP.@constraint(
            model,
            _initial_separation(problem, Ps[i], gamma0[i]) - eps * LinearAlgebra.I(d) in
            JuMP.PSDCone()
        )

        JuMP.@constraint(
            model,
            _unsafe_separation(problem, Ps[i], gammau[i]) - eps * LinearAlgebra.I(d) in
            JuMP.PSDCone()
        )

        # -I ⪯ P ⪯ I: the rest is homogeneous, so `max eps` is otherwise unbounded.
        JuMP.@constraint(model, LinearAlgebra.I(d) - Ps[i] in JuMP.PSDCone())
        JuMP.@constraint(model, Ps[i] + LinearAlgebra.I(d) in JuMP.PSDCone())
    end

    for edge in edges(graph)
        dynamics, scale = _edge_decrease(problem, graph, edge, A)
        add_decrease!(model, template, Ps[source(edge)], Ps[dest(edge)], dynamics; scale)
    end

    JuMP.@objective(model, Max, eps)

    model[:safety_P] = Ps
    model[:safety_gamma0] = gamma0
    model[:safety_gammau] = gammau
    model[:safety_eps] = eps

    return model
end

"""
    certify(template, graph, problem; optimizer)

Solve the barrier program and return a [`SafetyCertificate`](@ref).
"""
function certify(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::SafetyProblem;
    optimizer,
    check_path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem;
        optimizer = optimizer,
        check_path_complete = check_path_complete,
    )

    JuMP.optimize!(model)
    termination = JuMP.termination_status(model)

    JuMP.is_solved_and_feasible(model; allow_almost = true) || return SafetyCertificate(
        _failed(problem, template, graph, termination),
        nothing,
        nothing,
        nothing,
    )

    Ps = model[:safety_P]
    gamma0 = model[:safety_gamma0]
    gammau = model[:safety_gammau]
    eps = model[:safety_eps]

    Pval = [solution_value(template, P) for P in Ps]
    gamma0_val = JuMP.value.(gamma0)
    gammau_val = JuMP.value.(gammau)
    eps_val = JuMP.value(eps)

    # Re-check on the returned numbers rather than trusting the status.
    separated(S) =
        minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(S))) >=
        eps_val - _SAFETY_CHECK_TOLERANCE

    feasible =
        eps_val > _SAFETY_MARGIN_TOLERANCE && all(eachindex(Pval)) do i
            P = Matrix(Pval[i])
            return separated(_initial_separation(problem, P, gamma0_val[i])) &&
                   separated(_unsafe_separation(problem, P, gammau_val[i]))
        end

    return SafetyCertificate(
        CertificateData(problem, template, graph, Pval, termination, feasible),
        eps_val,
        gamma0_val,
        gammau_val,
    )
end

# Smallest margin counted as a separation; below it is solver noise.
const _SAFETY_MARGIN_TOLERANCE = 1e-8

# How far below the margin a separation of the solution may fall, as solver
# error.
const _SAFETY_CHECK_TOLERANCE = 1e-7

# The map x⁺ = A x in homogeneous coordinates.
function _homogeneous_dynamics(A::AbstractMatrix)
    n = size(A, 1)

    return [
        A zeros(n, 1)
        zeros(1, n) 1.0
    ]
end

# Validate the data and return the state dimension.
function _check_safety_data(
    graph::CertificateGraph,
    problem::SafetyProblem;
    check_path_complete::Bool = true,
)
    _require_one_mode_per_edge(graph, "SafetyProblem")
    return _check_modes(graph, problem.system; check_path_complete = check_path_complete)
end

# A barrier lives in homogeneous coordinates.
node_value(::AbstractTemplate, ::SafetyProblem, V, x::AbstractVector{<:Real}) =
    V([x; one(eltype(x))])

# Where the barrier is held; `refine` does not run on safety.
edge_slacks(certificate::SafetyCertificate) = _edge_slacks(certificate)
