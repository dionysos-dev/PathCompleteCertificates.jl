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
        Q::AbstractMatrix,
        R::AbstractMatrix,
    ) where {S}
        # Otherwise a two-mode autonomous system would be split into A and B.
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

        return new{typeof(system), typeof(Q), typeof(R)}(system, Q, R)
    end
end

"""
    OptimalControlCertificate

A state-feedback policy, `u = gains[a] * x` at node `a`, and an upper bound on
its value function, the minimum of the node quadratic forms. Calling the
certificate `c` as `c(x)` evaluates this bound.
"""
struct OptimalControlCertificate{D <: CertificateData, K} <: AbstractCertificate
    data::D
    gains::K
end

# P_src >= Q + K'RK + (A + BK)' P_dst (A + BK), convex only under S = P^-1,
# Y = K S; written on S, not P, so it is not an `add_decrease!` call.
function _add_edge_lmi!(
    model::JuMP.Model,
    problem::OptimalControlProblem,
    S_src,
    Y_src,
    S_dst,
    dynamics;
    psd_margin::Real,
)
    A, B = dynamics
    n = size(A, 1)
    m = size(B, 2)

    X11 = S_src
    X12 = S_src * transpose(A) + transpose(B * Y_src)
    X13 = S_src
    X14 = transpose(Y_src)
    X22 = S_dst
    X23 = zeros(n, n)
    X24 = zeros(n, m)
    X33 = inv(problem.Q)
    X34 = zeros(n, m)
    X44 = inv(problem.R)
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

Build, without solving, the optimal-control program in `S = P⁻¹`, `Y = KS`.
Only complete graphs and `QuadraticTemplate` are supported. `psd_margin` is the
strictness of every matrix inequality.
"""
function optimization_model(
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    psd_margin::Real = 1e-4,
    path_complete::Bool = true,
)
    template isa QuadraticTemplate ||
        throw(ArgumentError("optimal control currently supports only QuadraticTemplate"))
    psd_margin > 0 || throw(ArgumentError("psd_margin must be positive"))

    n = _check_optimal_control_data(graph, problem; path_complete = path_complete)
    A = state_matrices(problem.system)
    B = input_matrices(problem.system)
    m = size(first(B), 2)
    margin = psd_margin * Matrix{typeof(psd_margin)}(LinearAlgebra.I, n, n)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    S = [add_function_variables!(model, template, n, i) for i in nodes(graph)]
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
            problem,
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
    template::AbstractTemplate,
    graph::CertificateGraph,
    problem::OptimalControlProblem;
    optimizer,
    psd_margin::Real = 1e-4,
    path_complete::Bool = true,
)
    model = optimization_model(
        template,
        graph,
        problem;
        optimizer = optimizer,
        psd_margin = psd_margin,
        path_complete = path_complete,
    )

    JuMP.optimize!(model)
    termination = JuMP.termination_status(model)

    JuMP.is_solved_and_feasible(model; allow_almost = true) ||
        return OptimalControlCertificate(
            _failed(problem, template, graph, termination),
            nothing,
        )

    S = model[:optimal_control_S]
    Y = model[:optimal_control_Y]

    S_value = [JuMP.value.(matrix) for matrix in S]
    P = [QuadraticFunction(inv(LinearAlgebra.Symmetric(matrix))) for matrix in S_value]
    K = [JuMP.value.(Y[i]) * Matrix(P[i]) for i in eachindex(P)]

    return OptimalControlCertificate(
        CertificateData(problem, template, graph, P, termination, true),
        K,
    )
end

# Validate the data and return the state dimension.
function _check_optimal_control_data(graph, problem; path_complete::Bool = true)
    _require_one_mode_per_edge(graph, "OptimalControlProblem")
    n = _check_modes(graph, problem.system; path_complete = path_complete)

    # The bound is the plain minimum of Corollary III.3, which needs a complete graph.
    modes = n_modes(problem.system)
    is_complete(graph, 1:modes) || throw(
        ArgumentError(
            "optimal control currently supports only complete graphs; " *
            "the graph uses labels $(alphabet(graph)) and the " *
            "system has $modes modes",
        ),
    )

    return n
end

# --- The closed loop under the certificate's policy ---------------------------

"""
    simulate(certificate::OptimalControlCertificate, x0, modes; node = nothing)
    simulate(certificate::OptimalControlCertificate, x0, horizon::Integer;
             rng = Random.default_rng(), node = nothing)

Run the closed loop under the policy of `certificate` along `modes`, or along
`horizon` modes drawn uniformly at random, and return a [`Trajectory`](@ref).
The gain applied is that of the current graph node, which follows the observed
modes from `node`, by default the node whose function is smallest at `x0`.
"""
function simulate(
    certificate::OptimalControlCertificate,
    x0::AbstractVector{<:Real},
    modes::AbstractVector{<:Integer};
    node::Union{Nothing, Integer} = nothing,
)
    is_feasible(certificate) || throw(
        ArgumentError(
            "the certificate is infeasible ($(status(certificate))), so it " *
            "carries no policy to simulate",
        ),
    )

    system = problem(certificate).system
    graph_ = graph(certificate)
    _check_initial_state(system, x0)

    start = node === nothing ? argmin([V(x0) for V in functions(certificate)]) : node
    _check_node(graph_, start)

    successors = _successors(_letter_graph(graph_, "simulate"))
    current = Ref(start)

    policy = function (k, x)
        u = certificate.gains[current[]] * x
        current[] = _next_node(successors, current[], modes[k])
        return u
    end

    return _run(system, x0, modes, policy)
end

function simulate(
    certificate::OptimalControlCertificate,
    x0::AbstractVector{<:Real},
    horizon::Integer;
    rng::Random.AbstractRNG = Random.default_rng(),
    node::Union{Nothing, Integer} = nothing,
)
    modes = _random_modes(rng, problem(certificate).system, horizon)
    return simulate(certificate, x0, modes; node)
end

# The node the policy moves to when `mode` is observed at `node`.
function _next_node(successors, node::Integer, mode::Integer)
    haskey(successors, (node, mode)) || throw(
        ArgumentError(
            "the certificate graph has no edge labelled $mode out of node $node, " *
            "so the policy has nowhere to go: the graph is not complete for " *
            "this system's modes",
        ),
    )

    return first(successors[(node, mode)])
end
