import JuMP
import LinearAlgebra

"""
	OptimalControlProblem(system, Q, R)

Quadratic optimal-control problem for an input-enabled switched linear system.
The stage cost is `x'Q*x + u'R*u`, with `Q` and `R` symmetric positive
definite.
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
        # Without this, `mode_matrices` returns the bare `A` vector and the
        # destructuring below silently splits it into two mode matrices,
        # reporting a nonsense state dimension instead of the real problem.
        has_input(system) ||
            throw(ArgumentError("OptimalControlProblem requires a system with an input"))

        A = mode_matrices(system)
        B = input_matrices(system)
        isempty(A) && throw(ArgumentError("at least one mode is required"))

        n = size(first(A), 1)
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

A jointly synthesised state-feedback policy and the value-function bound it
comes with.

`gains` is one feedback matrix per node: at node `a` the policy is
`u = gains[a] * x`. The bound on the closed-loop value function is
`certificate(x)` — a function of the state, not a scalar.

`objective` is the solved log-determinant objective `Sum_i log det inv(P_i)`,
the volume heuristic that selects among the feasible certificates. It is a
solver diagnostic and **not** a bound on anything: it is routinely negative,
whereas the value function is nonnegative whenever `Q, R` are positive definite.
"""
struct OptimalControlCertificate{D <: CertificateData, K, T} <: AbstractCertificate
    data::D
    gains::K
    objective::T
end

# The one edge condition that does not factor through `add_domination!`, and it
# is worth being explicit about why rather than leaving it as an inconsistency.
#
# Domination is stated in the primal variables: `scale * V_src - V_dst . map`.
# Here the inequality is
#
#     P_src >= Q + K'RK + (A + BK)' P_dst (A + BK),
#
# which is not convex in (P, K) jointly. It becomes convex only after the
# substitution S = P^-1, Y = K S -- so this problem uses the template's
# variables as the *inverse* of the node function, and its constraint cannot be
# written against V_src and V_dst at all. A template that wants to support
# optimal control therefore has to supply a second primitive, which is why no
# template but the quadratic one does.
function add_edge_constraint!(
    model::JuMP.Model,
    problem::OptimalControlProblem,
    ::QuadraticTemplate,
    S_src,
    Y_src,
    S_dst,
    dynamics;
    psd_margin::Real = 1e-4,
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
	optimal_control_certificate(template, graph, problem; optimizer, psd_margin = 1e-4)

Synthesize a quadratic state-feedback policy and an upper bound on the closed-loop
value function for `problem`. This first implementation supports complete graphs
and `QuadraticTemplate` only.

Returns an [`OptimalControlCertificate`](@ref):

  * `functions(certificate)` are the node matrices and
    `gains` the feedback gains, one of each per node;
  * the value-function bound itself is `certificate(x)` — a function of the
    state, not a scalar;
  * `objective` is the solved log-determinant objective
    `Σᵢ log det Pᵢ⁻¹`, the volume heuristic that selects among the feasible
    certificates. It is a solver diagnostic, **not** a bound on the value
    function — it is routinely negative, whereas the value function is
    nonnegative whenever `Q, R ≻ 0`.
"""
function optimal_control_certificate(
    template::AbstractTemplate,
    graph::_HS.GraphAutomaton,
    problem::OptimalControlProblem;
    optimizer,
    psd_margin::Real = 1e-4,
    path_complete::Bool = true,
)
    template isa QuadraticTemplate ||
        throw(ArgumentError("optimal control currently supports only QuadraticTemplate"))
    psd_margin > 0 || throw(ArgumentError("psd_margin must be positive"))

    A = mode_matrices(problem.system)
    B = input_matrices(problem.system)
    _check_optimal_control_data(graph, A, B; path_complete = path_complete)

    node_list = collect(nodes(graph))
    n = size(first(A), 1)
    m = size(first(B), 2)
    margin = psd_margin * Matrix{typeof(psd_margin)}(LinearAlgebra.I, n, n)

    model = JuMP.Model(optimizer)
    JuMP.set_silent(model)

    S = [add_function_variables!(model, template, n, i) for i in eachindex(node_list)]
    Y = [
        JuMP.@variable(model, [1:m, 1:n], base_name = "Y_$i") for i in eachindex(node_list)
    ]
    t = JuMP.@variable(model, [1:length(node_list)], base_name = "t")

    for i in eachindex(node_list)
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
        mode = label(graph, edge)
        add_edge_constraint!(
            model,
            problem,
            template,
            S[source_index],
            Y[source_index],
            S[destination_index],
            (A[mode], B[mode]);
            psd_margin = psd_margin,
        )
    end

    JuMP.@objective(model, Max, sum(t))
    JuMP.optimize!(model)

    status = JuMP.termination_status(model)
    feasible = status in _FEASIBLE_TERMINATION_STATUSES
    if !feasible
        return OptimalControlCertificate(
            CertificateData(
                problem,
                template,
                graph,
                QuadraticFunction{Matrix{Float64}}[],
                status,
                false,
            ),
            nothing,
            nothing,
        )
    end

    S_value = [JuMP.value.(matrix) for matrix in S]
    P = [QuadraticFunction(inv(LinearAlgebra.Symmetric(matrix))) for matrix in S_value]
    K = [JuMP.value.(Y[i]) * P[i].P for i in eachindex(P)]

    return OptimalControlCertificate(
        CertificateData(problem, template, graph, P, status, true),
        K,
        JuMP.objective_value(model),
    )
end

function _check_optimal_control_data(graph, A, B; path_complete::Bool = true)
    n = _check_modes(graph, A; path_complete = path_complete)

    length(A) == length(B) ||
        throw(ArgumentError("A and B must have the same number of modes"))

    m = size(first(B), 2)

    for (mode, B_mode) in enumerate(B)
        size(B_mode) == (n, m) || throw(ArgumentError("B[$mode] must have size ($n, $m)"))
    end

    # Stricter than `_check_path_complete` on purpose: this problem reads its
    # bound off the plain minimum of Corollary III.3, which needs a *complete*
    # graph. A path-complete graph that is neither complete nor co-complete is
    # sound in general (Theorem III.8) but needs the observer aggregation,
    # which is not implemented here.
    is_complete(graph, 1:length(A)) || throw(
        ArgumentError(
            "optimal control currently supports only complete graphs; " *
            "the graph uses labels $(sort(collect(alphabet(graph)))) and the " *
            "system has $(length(A)) modes",
        ),
    )

    return nothing
end
