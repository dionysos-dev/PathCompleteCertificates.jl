"""
    OptimalControlProblem(system, Q, R)

Quadratic optimal-control problem for a switched linear system with an input
[ninite2026path](@cite). The stage cost is `x'Q*x + u'R*u`, with `Q`
and `R` symmetric positive definite.
"""
struct OptimalControlProblem{S, MQ <: AbstractMatrix, MR <: AbstractMatrix} <:
       AbstractProblem
    system::S
    Q::MQ
    R::MR

    function OptimalControlProblem(
        system::S,
        Q::MQ,
        R::MR,
    ) where {S, MQ <: AbstractMatrix, MR <: AbstractMatrix}
        has_input(system) ||
            throw(ArgumentError("OptimalControlProblem requires a system with an input"))

        B = input_matrices(system)
        n = _check_input_matrices(state_matrices(system), B)
        m = size(first(B), 2)
        size(Q) == (n, n) || throw(ArgumentError("Q must have size ($n, $n)"))
        size(R) == (m, m) || throw(ArgumentError("R must have size ($m, $m)"))
        isapprox(Q, transpose(Q)) || throw(ArgumentError("Q must be symmetric"))
        isapprox(R, transpose(R)) || throw(ArgumentError("R must be symmetric"))
        LinearAlgebra.isposdef(LinearAlgebra.Symmetric(Q)) ||
            throw(ArgumentError("Q must be positive definite"))
        LinearAlgebra.isposdef(LinearAlgebra.Symmetric(R)) ||
            throw(ArgumentError("R must be positive definite"))

        return new{S, MQ, MR}(system, Q, R)
    end
end

"""
    OptimalControlCertificate

A quadratic function `V_s` and a gain `K_s` at each node `s`.

- The policy is `u = K_s x`, where `s` minimizes `V_s(x)`; [`simulate`](@ref)
  runs it.
- Its cost from `x` is at most `min_s V_s(x)`. This bound is retrieved by
  calling the certificate at `x`.
"""
struct OptimalControlCertificate{D <: CertificateData, K} <: AbstractCertificate
    data::D
    gains::K
end

# P_src >= Q + K'RK + (A + BK)' P_dst (A + BK), convex only under S = P^-1,
# Y = K S; written on S, not P, so it is not an `add_decrease!` call.
function _add_edge_lmi!(
    model::JuMP.Model,
    cost,
    S_src,
    Y_src,
    S_dst,
    dynamics;
    psd_margin::Real,
)
    A, B = dynamics
    Q, R = cost
    n = size(A, 1)
    m = size(B, 2)

    X11 = S_src
    X12 = S_src * transpose(A) + transpose(B * Y_src)
    X13 = S_src
    X14 = transpose(Y_src)
    X22 = S_dst
    X23 = zeros(n, n)
    X24 = zeros(n, m)
    X33 = inv(Q)
    X34 = zeros(n, m)
    X44 = inv(R)
    margin = psd_margin * Matrix{typeof(psd_margin)}(LinearAlgebra.I, 3n + m, 3n + m)

    JuMP.@constraint(
        model,
        [
            X11 X12 X13 X14;
            transpose(X12) X22 X23 X24;
            transpose(X13) transpose(X23) X33 X34;
            transpose(X14) transpose(X24) transpose(X34) X44
        ] - margin in JuMP.PSDCone(),
    )

    return nothing
end

"""
    optimization_model(template, graph, problem; optimizer, psd_margin = 1e-4)

Build, without solving, the optimal-control program in `S = P⁻¹`, `Y = KS`. Only
complete graphs and `QuadraticTemplate` are supported.
"""
function optimization_model(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    psd_margin::Real = 1e-4,
)
    legacy = _legacy_quadratic(template, problem)
    psd_margin > 0 || throw(ArgumentError("psd_margin must be positive"))

    _check_optimal_control_data(graph, problem)
    n = _state_dimension(problem.system)
    A = state_matrices(problem.system)
    B = input_matrices(problem.system)
    m = size(first(B), 2)
    margin = psd_margin * Matrix{typeof(psd_margin)}(LinearAlgebra.I, n, n)
    scale = _cost_scale(problem)
    cost = (problem.Q / scale, problem.R / scale)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    S = [add_function_variables!(model, legacy, n, i) for i in nodes(graph)]
    Y = [JuMP.@variable(model, [1:m, 1:n], base_name = "Y_$i") for i in nodes(graph)]
    t = JuMP.@variable(model, [1:n_nodes(graph)], base_name = "t")

    for i in nodes(graph)
        JuMP.@constraint(model, S[i] - margin in JuMP.PSDCone())
        lower_triangular = [S[i][row, column] for row in 1:n for column in 1:row]
        JuMP.@constraint(
            model,
            [t[i]; 1; lower_triangular] in JuMP.MOI.LogDetConeTriangle(n),
        )
    end

    for edge in edges(graph)
        source_index = source(edge)
        destination_index = dest(edge)
        mode = only(letters(label(graph, edge)))
        _add_edge_lmi!(
            model,
            cost,
            S[source_index],
            Y[source_index],
            S[destination_index],
            (A[mode], B[mode]);
            psd_margin = psd_margin,
        )
    end

    JuMP.@objective(model, Max, sum(t))

    model[:optimal_control_S] = S
    model[:optimal_control_Y] = Y

    return model
end

"""
    certify(template, graph, problem; optimizer, psd_margin = 1e-4)

Synthesise a state-feedback policy and a bound on its value function, returned
as an [`OptimalControlCertificate`](@ref). Only complete graphs and
`QuadraticTemplate` are supported; the solver maximises `Σᵢ log det Pᵢ⁻¹`.
"""
function certify(
    template::_SetFamily,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    psd_margin::Real = 1e-4,
)
    model = optimization_model(template, graph, problem; optimizer, psd_margin)

    JuMP.optimize!(model)
    termination = JuMP.termination_status(model)

    JuMP.is_solved_and_feasible(model; allow_almost = true) ||
        return OptimalControlCertificate(
            _failed(problem, template, graph, termination),
            nothing,
        )

    S = model[:optimal_control_S]
    Y = model[:optimal_control_Y]

    # The model solved for the cost divided by its scale: `S = (P / scale)⁻¹`.
    # The value function scales with the cost, the gains do not.
    scaled = [inv(LinearAlgebra.Symmetric(JuMP.value.(matrix))) for matrix in S]
    P = [QuadraticFunction(_cost_scale(problem) * matrix) for matrix in scaled]
    K = [JuMP.value.(Y[i]) * scaled[i] for i in eachindex(scaled)]

    return OptimalControlCertificate(
        CertificateData(problem, template, graph, P, termination, true),
        K,
    )
end

# The edge inequality read back in `P` and `K`, which `_add_edge_lmi!` imposes
# in `S` and `Y`: the smallest eigenvalue of
# `P_src − Q − K'RK − (A + BK)' P_dst (A + BK)`, with `K` the source's gain.
function edge_slacks(certificate::OptimalControlCertificate)
    is_feasible(certificate) ||
        throw(ArgumentError("an infeasible certificate has no functions to measure"))

    problem_ = problem(certificate)
    graph_ = graph(certificate)
    P = Matrix.(functions(certificate))
    A = state_matrices(problem_.system)
    B = input_matrices(problem_.system)

    return map(edges(graph_)) do edge
        mode = only(letters(label(graph_, edge)))
        K = certificate.gains[source(edge)]
        closed_loop = A[mode] + B[mode] * K
        residual =
            P[source(edge)] - problem_.Q - transpose(K) * problem_.R * K -
            transpose(closed_loop) * P[dest(edge)] * closed_loop

        return minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(residual)))
    end
end

# The model is solved for `Q / k` and `R / k`, with `k` this scale, so that
# `psd_margin` does not depend on the units of the cost. Scaling the cost scales
# the value function by the same factor and keeps the gains.
_cost_scale(problem::OptimalControlProblem) =
    max(LinearAlgebra.opnorm(problem.Q), LinearAlgebra.opnorm(problem.R))

# Validate the data.
function _check_optimal_control_data(graph, problem)
    _require_one_mode_per_edge(graph, "OptimalControlProblem")
    # A complete graph is path-complete, so completeness below is the only check.
    _check_graph_suitability(graph, problem.system; check_path_complete = false)

    # The bound, the minimum of the node functions, and the policy, the gain of
    # the smallest node function, hold on a complete graph [ninite2026path].
    is_complete(graph, 1:n_modes(problem.system)) ||
        throw(ArgumentError("optimal control requires a complete graph"))

    return nothing
end

# --- The closed loop under the certificate's policy ---------------------------

"""
    simulate(certificate::OptimalControlCertificate, x0, modes)
    simulate(certificate::OptimalControlCertificate, x0, horizon::Integer;
             rng = Random.default_rng())

Run the closed loop under the policy of `certificate` along `modes`, or along
`horizon` modes drawn uniformly at random, and return a [`Trajectory`](@ref).
At each state `x`, the policy applies the gain of the node whose function is
smallest at `x`: `u = K_s x` with `s ∈ argmin V_s(x)` [ninite2026path](@cite).
"""
function simulate(
    certificate::OptimalControlCertificate,
    x0::AbstractVector{<:Real},
    modes::AbstractVector{<:Integer},
)
    is_feasible(certificate) || throw(
        ArgumentError(
            "the certificate is infeasible ($(status(certificate))), so it " *
            "carries no policy to simulate",
        ),
    )

    system = problem(certificate).system
    _check_initial_state(system, x0)

    Vs = functions(certificate)
    policy(_, x) = certificate.gains[argmin([V(x) for V in Vs])] * x

    return _run(system, x0, modes, policy)
end

function simulate(
    certificate::OptimalControlCertificate,
    x0::AbstractVector{<:Real},
    horizon::Integer;
    rng::Random.AbstractRNG = Random.default_rng(),
)
    modes = _random_modes(rng, problem(certificate).system, horizon)
    return simulate(certificate, x0, modes)
end
