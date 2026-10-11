import JuMP
import LinearAlgebra

"""
    OptimalControlProblem(system, Q, R)

Quadratic optimal-control problem for a switched linear system with an input
(Ninite, Banse, Berger & Jungers). The stage cost is `x'Q*x + u'R*u`, with `Q`
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
        # Without this the destructuring below silently splits a two-mode
        # autonomous system into A and B, reporting a nonsense dimension.
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
`certificate(x)`, a function of the state, and `functions(certificate)` are the
quadratic forms it is the minimum of.
"""
struct OptimalControlCertificate{D <: CertificateData, K} <: AbstractCertificate
    data::D
    gains::K
end

# The one edge condition that does not factor through `add_domination!`, so it
# is not an `add_edge_constraint!` method: that signature takes two node
# functions, and this inequality,
#
#     P_src >= Q + K'RK + (A + BK)' P_dst (A + BK),
#
# is convex only under S = P^-1, Y = K S. It is written on the quadratic
# template's variables as the *inverse* of the node function, which is why only
# that template supports it.
function _add_edge_lmi!(
    model::JuMP.Model,
    problem::OptimalControlProblem,
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
    optimization_model(template, graph, problem; optimizer, psd_margin = 1e-4)

Build the optimal-control program without solving it.

Supports complete graphs and `QuadraticTemplate` only; see
[`certify`](@ref) for what the solved program yields.
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

    A = mode_matrices(problem.system)
    B = input_matrices(problem.system)
    _check_optimal_control_data(graph, problem; path_complete = path_complete)

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

Synthesize a quadratic state-feedback policy and an upper bound on the closed-loop
value function for `problem`. This first implementation supports complete graphs
and `QuadraticTemplate` only.

Returns an [`OptimalControlCertificate`](@ref): `functions(certificate)` are
the node matrices and `gains` the feedback gains, one of each per node, and the
value-function bound is `certificate(x)`, a function of the state. Among the
feasible certificates the solver picks the one of largest volume, by the
log-determinant objective `Σᵢ log det Pᵢ⁻¹`.
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
    status = JuMP.termination_status(model)

    status in _FEASIBLE_TERMINATION_STATUSES ||
        return OptimalControlCertificate(_failed(problem, template, graph, status), nothing)

    S = model[:optimal_control_S]
    Y = model[:optimal_control_Y]

    S_value = [JuMP.value.(matrix) for matrix in S]
    P = [QuadraticFunction(inv(LinearAlgebra.Symmetric(matrix))) for matrix in S_value]
    K = [JuMP.value.(Y[i]) * P[i].P for i in eachindex(P)]

    return OptimalControlCertificate(
        CertificateData(problem, template, graph, P, status, true),
        K,
    )
end

function _check_optimal_control_data(graph, problem; path_complete::Bool = true)
    _require_one_mode_per_edge(graph, "OptimalControlProblem")
    n = _check_modes(graph, problem.system; path_complete = path_complete)
    A = mode_matrices(problem.system)
    B = input_matrices(problem.system)

    length(A) == length(B) ||
        throw(ArgumentError("A and B must have the same number of modes"))

    m = size(first(B), 2)

    for (mode, B_mode) in enumerate(B)
        size(B_mode) == (n, m) || throw(ArgumentError("B[$mode] must have size ($n, $m)"))
    end

    # Stricter than `_check_path_complete`: the bound is read off the plain
    # minimum of Corollary III.3, which needs a *complete* graph. The general
    # case is sound (Theorem III.8) but needs the common function over the observer.
    is_complete(graph, 1:length(A)) || throw(
        ArgumentError(
            "optimal control currently supports only complete graphs; " *
            "the graph uses labels $(sort(collect(alphabet(graph)))) and the " *
            "system has $(length(A)) modes",
        ),
    )

    return nothing
end
