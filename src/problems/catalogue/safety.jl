import JuMP
import LinearAlgebra

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

        A = mode_matrices(system)

        isempty(A) && throw(ArgumentError("at least one mode is required"))

        n = size(first(A), 1)
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

# `B_dst(A x) <= B_src(x)` with no margin: every lifted map fixes [0, …, 0, 1],
# so a margin would sum to `0 >= L * margin` around a cycle.
function add_edge_constraint!(
    model::JuMP.Model,
    ::SafetyProblem,
    template::AbstractTemplate,
    P_src,
    P_dst,
    A::AbstractMatrix;
    scale::Real = 1,
)
    add_decrease!(model, template, P_src, P_dst, _homogeneous_dynamics(A))

    return nothing
end

"""
    optimization_model(template, graph, problem; optimizer)

Build, without solving, the barrier program; only `QuadraticTemplate` is supported.
"""
function optimization_model(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::SafetyProblem;
    optimizer,
    path_complete::Bool = true,
)
    template isa QuadraticTemplate ||
        throw(ArgumentError("SafetyProblem currently supports only QuadraticTemplate"))

    A = mode_matrices(problem.system)
    _check_safety_data(graph, A, problem; path_complete = path_complete)

    node_list = collect(nodes(graph))
    n_nodes = length(node_list)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    n = size(first(A), 1)
    d = n + 1

    # No PSD constraint on the barriers: it would force P = 0.
    Ps = [add_function_variables!(model, template, d, i) for i in 1:n_nodes]

    gamma0 =
        [JuMP.@variable(model, lower_bound = 0, base_name = "gamma0_$i") for i in 1:n_nodes]

    gammau =
        [JuMP.@variable(model, lower_bound = 0, base_name = "gammau_$i") for i in 1:n_nodes]

    eps = JuMP.@variable(model, lower_bound = 0, base_name = "eps")

    for i in 1:n_nodes
        JuMP.@constraint(
            model,
            -(Ps[i] + gamma0[i] * problem.S0) - eps * LinearAlgebra.I(d) in JuMP.PSDCone()
        )

        JuMP.@constraint(
            model,
            Ps[i] - gammau[i] * problem.Su - eps * LinearAlgebra.I(d) in JuMP.PSDCone()
        )

        # -I ⪯ P ⪯ I: the rest is homogeneous, so `max eps` is otherwise unbounded.
        JuMP.@constraint(model, LinearAlgebra.I(d) - Ps[i] in JuMP.PSDCone())
        JuMP.@constraint(model, Ps[i] + LinearAlgebra.I(d) in JuMP.PSDCone())
    end

    for edge in edges(graph)
        i = source(edge)
        j = dest(edge)

        add_edge_constraint!(
            model,
            problem,
            template,
            Ps[i],
            Ps[j],
            A[only(letters(label(graph, edge)))],
        )
    end

    JuMP.@objective(model, Max, eps)

    model[:safety_P] = Ps
    model[:safety_gamma0] = gamma0
    model[:safety_gammau] = gammau
    model[:safety_eps] = eps
    model[:safety_nodes] = node_list

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
    path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem;
        optimizer = optimizer,
        path_complete = path_complete,
    )

    JuMP.optimize!(model)

    status = JuMP.termination_status(model)

    if !(status in _FEASIBLE_TERMINATION_STATUSES)
        return SafetyCertificate(
            _failed(problem, template, graph, status),
            nothing,
            nothing,
            nothing,
        )
    end

    Ps = model[:safety_P]
    gamma0 = model[:safety_gamma0]
    gammau = model[:safety_gammau]
    eps = model[:safety_eps]

    Pval = [solution_value(template, P) for P in Ps]
    gamma0_val = JuMP.value.(gamma0)
    gammau_val = JuMP.value.(gammau)
    eps_val = JuMP.value(eps)

    # Re-check on the returned numbers rather than trusting the status.
    feas = eps_val > _SAFETY_MARGIN_TOLERANCE

    for i in eachindex(Pval)
        initial_margin = LinearAlgebra.Symmetric(-(Pval[i].P + gamma0_val[i] * problem.S0))

        unsafe_margin = LinearAlgebra.Symmetric(Pval[i].P - gammau_val[i] * problem.Su)

        if minimum(LinearAlgebra.eigvals(initial_margin)) < eps_val - 1e-7 ||
           minimum(LinearAlgebra.eigvals(unsafe_margin)) < eps_val - 1e-7
            feas = false
            break
        end
    end

    return SafetyCertificate(
        CertificateData(problem, template, graph, Pval, status, feas),
        eps_val,
        gamma0_val,
        gammau_val,
    )
end

# Smallest margin counted as a separation; below it is solver noise.
const _SAFETY_MARGIN_TOLERANCE = 1e-8

# The map x⁺ = A x in homogeneous coordinates.
function _homogeneous_dynamics(A::AbstractMatrix)
    n = size(A, 1)

    return [
        A zeros(n, 1)
        zeros(1, n) 1.0
    ]
end

function _check_safety_data(
    graph::CertificateGraph,
    A::AbstractVector{<:AbstractMatrix},
    problem::SafetyProblem;
    path_complete::Bool = true,
)
    _require_one_mode_per_edge(graph, "SafetyProblem")
    _check_modes(graph, problem.system; path_complete = path_complete)

    return nothing
end

# A barrier lives in homogeneous coordinates.
function node_value(
    ::QuadraticTemplate,
    ::SafetyProblem,
    V::QuadraticFunction,
    x::AbstractVector{<:Real},
)
    return V([x; one(eltype(x))])
end

# --- What refine reads: smaller is better, and where the barrier is held -----

objective(certificate::SafetyCertificate) = -certificate.margin

function edge_slacks(certificate::SafetyCertificate)
    is_feasible(certificate) ||
        throw(ArgumentError("an infeasible certificate has no functions to measure"))

    graph_ = graph(certificate)
    template_ = template(certificate)
    B = functions(certificate)
    A = mode_matrices(problem(certificate).system)

    return map(edges(graph_)) do edge
        return decrease_slack(
            template_,
            B[source(edge)],
            B[dest(edge)],
            _homogeneous_dynamics(A[only(letters(label(graph_, edge)))]),
        )
    end
end
