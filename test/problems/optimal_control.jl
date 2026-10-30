module TestOptimalControl

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import HiGHS
import Clarabel
import JuMP
import LinearAlgebra
import Random
import SetProg
using SumOfSquares

# Clarabel's chordal decomposition errors inside `psd_completion!` on the block
# LMI this problem builds. The solves here are small, so switch it off.
const OPTIMIZER = JuMP.optimizer_with_attributes(
    Clarabel.Optimizer,
    "chordal_decomposition_enable" => false,
)

const A = [[0.0 1.0; -1.0 0.0], [-0.1 0.0; 0.0 -0.95]]
const B = [[1.0; 0.0;;], [1.0; 0.0;;]]
const Q = [1.0 0.0; 0.0 1.0]
const R = [1.0;;]

const SYSTEM = PCC.switched_system(A, B)
const PROBLEM = PCC.OptimalControlProblem(SYSTEM, Q, R)
const GRAPH = PCC.de_bruijn(1, 2)

const RESULT = PCC.certify(PCC.QuadraticTemplate(), GRAPH, PROBLEM; optimizer = OPTIMIZER)

@testset "a certificate is produced" begin
    @test PCC.template(RESULT) == PCC.QuadraticTemplate()
    @test PCC.is_feasible(RESULT)
    @test length(PCC.functions(RESULT)) == PCC.n_nodes(GRAPH)
    @test length(RESULT.gains) == PCC.n_nodes(GRAPH)

    for V in PCC.functions(RESULT)
        @test LinearAlgebra.isposdef(LinearAlgebra.Symmetric(Matrix(V)))
    end

    for K in RESULT.gains
        @test size(K) == (size(first(B), 2), size(first(A), 1))
    end
end

@testset "the synthesized gains satisfy the Bellman inequality on every edge" begin
    # The solver reporting OPTIMAL is not the certificate. Check the inequality
    # the certificate actually claims:
    #     P_a  >=  Q + K_a' R K_a + (A_i + B_i K_a)' P_b (A_i + B_i K_a)
    for edge in PCC.edges(GRAPH)
        a = PCC.source(edge)
        b = PCC.dest(edge)
        i = PCC.label(GRAPH, edge)

        K = RESULT.gains[a]
        closed_loop = A[i] + B[i] * K
        residual =
            Matrix(PCC.functions(RESULT)[a]) - (
                Q +
                transpose(K) * R * K +
                transpose(closed_loop) * Matrix(PCC.functions(RESULT)[b]) * closed_loop
            )

        @test minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(Matrix(residual)))) >
              -1e-6
    end
end

@testset "edge_slacks reads the same inequality, so tight_edges applies" begin
    slacks = PCC.edge_slacks(RESULT)

    @test length(slacks) == PCC.n_edges(GRAPH)
    @test all(>(-1e-6), slacks)
    @test PCC.tight_edges(RESULT; atol = minimum(slacks)) ==
          [e for (e, s) in zip(PCC.edges(GRAPH), slacks) if s <= minimum(slacks)]
end

@testset "the bound is a function of the state, and nonnegative" begin
    @test RESULT([1.0, 1.0]) > 0
    @test PCC.common(GRAPH, PROBLEM, PCC.functions(RESULT), [1.0, 1.0]) > 0
end

@testset "SetProg inclusions preserve the original optimal-control SDP" begin
    cost_Q = [2.0 0.25; 0.25 1.5]
    cost_R = [3.0;;]
    problem = PCC.OptimalControlProblem(SYSTEM, cost_Q, cost_R)
    model = PCC.optimization_model(
        PCC.QuadraticTemplate(),
        GRAPH,
        problem;
        optimizer = OPTIMIZER,
    )
    S = model[:optimal_control_S]
    Y = model[:optimal_control_Y]
    margin = 1e-4
    scale = PCC._cost_scale(problem)
    n, m = size(first(A), 1), size(first(B), 2)
    expected = []
    canonical(M) = vec(convert.(JuMP.AffExpr, M))
    for matrix in S
        push!(expected, canonical(matrix - margin * LinearAlgebra.I))
    end
    for edge in PCC.edges(GRAPH)
        a, b = PCC.source(edge), PCC.dest(edge)
        mode = only(PCC.letters(PCC.label(GRAPH, edge)))
        M =
            [
                S[a] S[a]*A[mode]'+(B[mode]*Y[a])' S[a] Y[a]';
                A[mode]*S[a]+B[mode]*Y[a] S[b] zeros(n, n) zeros(n, m);
                S[a] zeros(n, n) inv(cost_Q / scale) zeros(n, m);
                Y[a] zeros(m, n) zeros(m, n) inv(cost_R / scale)
            ] - margin * LinearAlgebra.I
        push!(expected, canonical(M))
    end
    actual = [
        JuMP.constraint_object(c).func for c in JuMP.all_constraints(
            model,
            Vector{JuMP.AffExpr},
            JuMP.MOI.PositiveSemidefiniteConeSquare,
        )
    ]
    @test length(actual) == PCC.n_nodes(GRAPH) + PCC.n_edges(GRAPH)
    for matrix in expected
        index = findfirst(
            candidate ->
                length(candidate) == length(matrix) &&
                all(JuMP.isequal_canonical.(candidate, matrix)),
            actual,
        )
        @test index !== nothing
        index === nothing || deleteat!(actual, index)
    end
    @test isempty(actual)
    @test JuMP.num_variables(model) == PCC.n_nodes(GRAPH) * (div(n * (n + 1), 2) + m*n + 1)
    @test JuMP.num_constraints(model; count_variable_in_set_constraints = true) ==
          2PCC.n_nodes(GRAPH) + PCC.n_edges(GRAPH)
    @test length(JuMP.list_of_constraint_types(model)) == 2
    logs = JuMP.all_constraints(model, Vector{JuMP.AffExpr}, JuMP.MOI.LogDetConeTriangle)
    @test length(logs) == PCC.n_nodes(GRAPH)
    for (i, c) in enumerate(logs)
        f = JuMP.constraint_object(c).func
        @test JuMP.isequal_canonical(f[2], JuMP.AffExpr(1.0))
        @test all(
            JuMP.isequal_canonical.(
                f[3:end],
                [
                    convert(JuMP.AffExpr, S[i][row, column]) for row in 1:n for
                    column in 1:row
                ],
            ),
        )
    end
    @test JuMP.objective_sense(model) == JuMP.MOI.MAX_SENSE
    @test JuMP.isequal_canonical(
        JuMP.objective_function(model),
        sum(JuMP.constraint_object(c).func[1] for c in logs),
    )
end

@testset "the units of the cost do not change the answer" begin
    # Scaling Q and R by c scales the value function by c and keeps the gains;
    # unnormalized, psd_margin = 1e-4 made Q = 1000 I infeasible.
    c = 1e3
    scaled = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PCC.OptimalControlProblem(SYSTEM, c * Q, c * R);
        optimizer = OPTIMIZER,
    )

    @test PCC.is_feasible(scaled)
    @test scaled([1.0, 1.0]) ≈ c * RESULT([1.0, 1.0]) rtol = 1e-3
    @test all(isapprox.(scaled.gains, RESULT.gains; rtol = 1e-3))
end

@testset "input validation" begin
    @test_throws ArgumentError PCC.OptimalControlProblem(SYSTEM, Q, [-1.0;;])   # R not pd
    @test_throws ArgumentError PCC.OptimalControlProblem(SYSTEM, -Q, R)         # Q not pd
    @test_throws ArgumentError PCC.OptimalControlProblem(SYSTEM, Q[1:1, 1:1], R)

    @test_throws ArgumentError PCC.certify(
        PCC.LinearCopositiveTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
    )

    @test_throws ArgumentError PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        psd_margin = 0.0,
    )

    # A system with no input is not an optimal-control problem. Without the
    # guard, `A, B = state_matrices(system)` splits the two mode matrices into
    # A and B and reports a nonsense state dimension.
    @test_throws ArgumentError PCC.OptimalControlProblem(PCC.switched_system(A), Q, R)

    # Only path-complete graphs are supported for now.
    incomplete = GraphAutomaton(2)
    add_transition!(incomplete, 1, 2, 1)
    add_transition!(incomplete, 2, 1, 1)
    add_transition!(incomplete, 1, 1, 2)

    @test_throws ArgumentError PCC.certify(
        PCC.QuadraticTemplate(),
        incomplete,
        PROBLEM;
        optimizer = OPTIMIZER,
    )

    # Complete for its own alphabet, but blind to the system's second mode.
    mode_1_only = GraphAutomaton(1)
    add_transition!(mode_1_only, 1, 1, 1)

    @test PCC.is_path_complete(mode_1_only)
    @test_throws ArgumentError PCC.certify(
        PCC.QuadraticTemplate(),
        mode_1_only,
        PROBLEM;
        optimizer = OPTIMIZER,
    )
end

# --- The closed loop: the gain applied at each step is that of the node whose
# function is smallest at the current state, which the replay below recomputes.

@testset "the certificate drives the loop" begin
    @test PCC.is_feasible(RESULT)

    rng = Random.MersenneTwister(3)
    trajectory = PCC.simulate(RESULT, [1.0, 1.0], 20; rng = rng)

    @test PCC.has_input(trajectory)
    @test length(trajectory) == 20
    @test length(PCC.inputs(trajectory)) == 20
    @test length(PCC.states(trajectory)) == 21
end

@testset "the gain at each step is that of the smallest node function" begin
    rng = Random.MersenneTwister(3)
    trajectory = PCC.simulate(RESULT, [1.0, 1.0], 20; rng = rng)

    xs = PCC.states(trajectory)
    us = PCC.inputs(trajectory)
    chosen = Int[]

    for (k, mode) in enumerate(PCC.switching(trajectory))
        node = argmin([V(xs[k]) for V in PCC.functions(RESULT)])
        push!(chosen, node)

        @test us[k] ≈ RESULT.gains[node] * xs[k]
        @test xs[k + 1] ≈ A[mode] * xs[k] + B[mode] * us[k]
    end

    # More than one gain was applied, so the test above is not vacuous.
    @test length(Set(chosen)) > 1
end

@testset "the cost of a run is at most the bound at its start" begin
    x0 = [1.0, 1.0]
    trajectory = PCC.simulate(RESULT, x0, 200; rng = Random.MersenneTwister(4))
    cost = sum(
        x' * Q * x + u' * R * u for
        (x, u) in zip(PCC.states(trajectory), PCC.inputs(trajectory))
    )

    @test cost <= RESULT(x0) + 1e-6
end

@testset "the closed loop contracts" begin
    rng = Random.MersenneTwister(5)
    xs = PCC.states(PCC.simulate(RESULT, [1.0, 1.0], 40; rng = rng))

    @test LinearAlgebra.norm(last(xs)) < LinearAlgebra.norm(first(xs))
end

@testset "input validation" begin
    @test_throws ArgumentError PCC.simulate(RESULT, [1.0, 1.0, 1.0], 5)
    @test_throws ArgumentError PCC.simulate(RESULT, [1.0, 1.0], -1)
end

@testset "the closed loop along given modes" begin
    x0 = [1.0, 1.0]
    trajectory = PCC.simulate(RESULT, x0, [1, 2, 2])
    node = argmin([V(x0) for V in PCC.functions(RESULT)])

    @test PCC.switching(trajectory) == [1, 2, 2]
    @test first(PCC.inputs(trajectory)) ≈ RESULT.gains[node] * x0
end

@testset "Quartic value bounds for supplied and initialized gains" begin
    system = PCC.switched_system([[0.5;;]], [[1.0;;]])
    graph = PCC.common_graph(system)
    problem = PCC.OptimalControlProblem(system, [1.0;;], [1.0;;]; p = 4)
    family = SetProg.PolySet(
        symmetric = true,
        convex = true,
        psd = false,
        degree = 4,
        basis = Chebyshev,
    )
    gains = [[-0.1;;]]
    model = PCC.optimization_model(family, graph, problem; optimizer = OPTIMIZER, gains)
    @test !only(model[:optimal_control_sets]).set.psd
    @test length(SetProg.data(model).constraints) == PCC.n_edges(graph)
    result = PCC.certify(family, graph, problem; optimizer = OPTIMIZER, gains)
    @test PCC.is_feasible(result)
    @test only(PCC.functions(result)) isa SetProg.Sets.ConvexPolySet
    @test result.gains == gains
    expected = (1 + 0.1^4) / (1 - 0.4^4)
    @test result([1.0]) ≈ expected rtol = 1e-5
    @test result([2.0]) ≈ 16expected rtol = 1e-5
    @test all(>=(-1e-7), PCC.edge_slacks(result))
    trajectory = PCC.simulate(result, [2.0], 100; rng = Random.MersenneTwister(7))
    accumulated = sum(
        (x[1]^2)^2 + (u[1]^2)^2 for
        (x, u) in zip(PCC.states(trajectory), PCC.inputs(trajectory))
    )
    @test accumulated <= result([2.0]) + 1e-6
    @test abs(only(last(PCC.states(trajectory)))) < 1e-6
    for state in ([-2.0], [-0.25], [0.0], [1.0])
        @test result(state) >= (state[1]^2)^2 + (0.1state[1])^4 + result(0.4state) - 1e-6
    end
    # The certificate owns its gain matrices.
    gains[1][1] = 0.0
    @test only(result.gains)[1] == -0.1
    initialized = PCC.certify(family, graph, problem; optimizer = OPTIMIZER)
    @test PCC.is_feasible(initialized)
    @test all(>=(-1e-7), PCC.edge_slacks(initialized))

    scaled_problem = PCC.OptimalControlProblem(system, [100.0;;], [100.0;;]; p = 4)
    scaled = PCC.certify(
        family,
        graph,
        scaled_problem;
        optimizer = OPTIMIZER,
        gains = result.gains,
    )
    @test PCC.is_feasible(scaled)
    @test scaled([1.0]) ≈ 100^2 * result([1.0]) rtol = 1e-5
    positive_margin = PCC.certify(
        family,
        graph,
        problem;
        optimizer = OPTIMIZER,
        gains = result.gains,
        margin = 1e-4,
    )
    @test PCC.is_feasible(positive_margin)
    @test positive_margin([1.0]) > result([1.0])
    unstable = PCC.OptimalControlProblem(
        PCC.switched_system([[1.2;;]], [[1.0;;]]),
        [1.0;;],
        [1.0;;];
        p = 4,
    )
    failed = PCC.certify(family, graph, unstable; optimizer = OPTIMIZER, gains = [[0.0;;]])
    @test !PCC.is_feasible(failed)
    @test_throws ArgumentError PCC.edge_slacks(failed)
    @test_throws ArgumentError PCC.simulate(failed, [1.0], 1)
    @test_throws ArgumentError PCC.optimization_model(
        family,
        graph,
        problem;
        optimizer = OPTIMIZER,
        gains = [],
    )
    @test_throws DimensionMismatch PCC.optimization_model(
        family,
        graph,
        problem;
        optimizer = OPTIMIZER,
        gains = [zeros(1, 2)],
    )
    @test_throws ArgumentError PCC.optimization_model(
        family,
        graph,
        problem;
        optimizer = OPTIMIZER,
        gains = [[NaN;;]],
    )
    @test_throws ArgumentError PCC.optimization_model(
        family,
        graph,
        problem;
        optimizer = OPTIMIZER,
        gains = result.gains,
        margin = -1,
    )
    @test_throws MethodError PCC.optimization_model(
        family,
        graph,
        PCC.OptimalControlProblem(system, [1.0;;], [1.0;;]);
        optimizer = OPTIMIZER,
        gains = result.gains,
    )
    @test_throws MethodError PCC.certify(
        SetProg.PolySet(symmetric = true, degree = 4),
        graph,
        problem;
        optimizer = OPTIMIZER,
    )
    @test_throws MethodError PCC.certify(
        SetProg.PolySet(symmetric = true, convex = true, degree = 0:4),
        graph,
        problem;
        optimizer = OPTIMIZER,
    )
    uncontrollable = PCC.OptimalControlProblem(
        PCC.switched_system([[1.2;;]], [[0.0;;]]),
        [1.0;;],
        [1.0;;];
        p = 4,
    )
    @test_throws ArgumentError PCC.certify(
        family,
        graph,
        uncontrollable;
        optimizer = OPTIMIZER,
    )
    @test_throws ArgumentError PCC.OptimalControlProblem(system, [1.0;;], [1.0;;]; p = 0)
end

@testset "Quartic switching control in two dimensions" begin
    objectives = Dict{Bool, Float64}()
    for basis in (Monomial, Chebyshev), psd in (true, false)
        matrices = [[0.5 0.1; 0.0 0.4], [0.3 0.0; -0.1 0.4]]
        inputs = [[1.0; 0.2;;], [1.0; 0.2;;]]
        system = PCC.switched_system(matrices, inputs)
        graph = PCC.de_bruijn(1, 2)
        problem = PCC.OptimalControlProblem(system, [2.0 0.25; 0.25 1.0], [1.0;;]; p = 4)
        family = SetProg.PolySet(
            symmetric = true,
            convex = true,
            degree = 4,
            psd = psd,
            basis = basis,
        )
        gains = [zeros(1, 2), [-0.1 0.05]]
        result = PCC.certify(family, graph, problem; optimizer = OPTIMIZER, gains)
        @test PCC.is_feasible(result)
        @test length(PCC.functions(result)) == 2
        @test all(V -> V isa SetProg.Sets.ConvexPolySet, PCC.functions(result))
        @test PCC._prepared_families(family, 2, 2)[1].basis == basis
        integral = sum(V -> SetProg.l1_integral(V, ones(2)), PCC.functions(result))
        if basis == Monomial
            objectives[psd] = integral
        else
            @test integral ≈ objectives[psd] rtol = 1e-5
        end
        for V in PCC.functions(result)
            p = SumOfSquares.MP.polynomial(V.p)
            @test all(
                t ->
                    SumOfSquares.MP.degree(t) == 4 ||
                    abs(SumOfSquares.MP.coefficient(t)) <= 1e-6,
                SumOfSquares.MP.terms(p),
            )
        end
        @test all(>=(-1e-6), PCC.edge_slacks(result))
        for edge in PCC.edges(graph), angle in range(0, 2pi; length = 17)
            x = [cos(angle), sin(angle)]
            a, b = PCC.source(edge), PCC.dest(edge)
            mode = only(PCC.letters(PCC.label(graph, edge)))
            u = gains[a] * x
            lhs = PCC.node_value(problem, PCC.functions(result)[a], x)
            next = matrices[mode] * x + inputs[mode] * u
            rhs =
                (x' * problem.Q * x)^2 +
                (u' * problem.R * u)^2 +
                PCC.node_value(problem, PCC.functions(result)[b], next)
            @test lhs >= rhs - 1e-5
        end
        for seed in 1:3
            trajectory =
                PCC.simulate(result, [1.0, -0.5], 50; rng = Random.MersenneTwister(seed))
            cost = sum(
                (x' * problem.Q * x)^2 + (u' * problem.R * u)^2 for
                (x, u) in zip(PCC.states(trajectory), PCC.inputs(trajectory))
            )
            @test cost <= result([1.0, -0.5]) + 1e-5
            @test LinearAlgebra.norm(last(PCC.states(trajectory))) < 1e-6
        end
    end
end

@testset "Polyhedral control values" begin
    P = SetProg.Polyhedra
    library = P.DefaultLibrary{Float64}(HiGHS.Optimizer)
    partition = P.polyhedron(P.hrep([1.0; -1.0;;], ones(2)), library)
    family = SetProg.Polytope(symmetric = true, piecewise = partition)
    system = PCC.switched_system([[0.5;;]], [[1.0;;]])
    graph = PCC.common_graph(system)
    gains = [[-0.1;;]]
    for p in (1, 2), scale in (1.0, 100.0)
        problem = PCC.OptimalControlProblem(system, [scale;;], [scale;;]; p)
        result = PCC.certify(family, graph, problem; optimizer = OPTIMIZER, gains)
        @test PCC.is_feasible(result)
        expected = scale^(p/2) * (1 + 0.1^p) / (1 - 0.4^p)
        for x in ([-2.0], [-0.5], [0.0], [1.0])
            @test result(x) ≈ expected * abs(x[1])^p rtol = 1e-5 atol = 1e-7
            @test result(x) >= scale^(p/2) * (1 + 0.1^p) * abs(x[1])^p + result(0.4x) - 1e-5
        end
        @test all(>=(-1e-6), PCC.edge_slacks(result))
        trajectory = PCC.simulate(result, [2.0], 100; rng = Random.MersenneTwister(3))
        accumulated = sum(
            scale^(p/2) * (abs(x[1])^p + abs(u[1])^p) for
            (x, u) in zip(PCC.states(trajectory), PCC.inputs(trajectory))
        )
        @test accumulated <= result([2.0]) + 1e-5
        model = PCC.optimization_model(family, graph, problem; optimizer = OPTIMIZER, gains)
        JuMP.optimize!(model)
        @test !any(
            t ->
                t[2] <: Union{
                    JuMP.MOI.PositiveSemidefiniteConeTriangle,
                    JuMP.MOI.PositiveSemidefiniteConeSquare,
                },
            JuMP.list_of_constraint_types(model),
        )
        @test JuMP.num_constraints(model, Vector{JuMP.AffExpr}, JuMP.MOI.SecondOrderCone) ==
              (p == 2 ? 2 : 0)
    end
    for p in (1, 2)
        problem = PCC.OptimalControlProblem(system, partition, partition; p)
        result = PCC.certify(family, graph, problem; optimizer = OPTIMIZER, gains)
        @test PCC.is_feasible(result)
        @test result([2.0]) ≈ 2^p * (1 + 0.1^p)/(1 - 0.4^p) rtol = 1e-5
        initialized = PCC.certify(family, graph, problem; optimizer = OPTIMIZER)
        @test PCC.is_feasible(initialized)
    end
end

@testset "Switching polyhedral Bellman bounds" begin
    P = SetProg.Polyhedra
    library = P.DefaultLibrary{Float64}(HiGHS.Optimizer)
    partition =
        P.polyhedron(P.hrep([1.0 0.0; -1.0 0.0; 0.0 1.0; 0.0 -1.0], ones(4)), library)
    input_cost = P.polyhedron(P.hrep([1.0; -1.0;;], ones(2)), library)
    matrices = [[0.4 0.1; 0.0 0.3], [0.3 0.0; -0.1 0.4]]
    inputs = [[1.0; 0.0;;], [0.0; 1.0;;]]
    system = PCC.switched_system(matrices, inputs)
    graph = PCC.de_bruijn(1, 2)
    family = SetProg.Polytope(symmetric = true, piecewise = partition)
    gains = [[-0.05 -0.05] for _ in PCC.nodes(graph)]
    for p in (1, 2)
        problem = PCC.OptimalControlProblem(system, partition, input_cost; p)
        optimizer = p == 1 ? HiGHS.Optimizer : OPTIMIZER
        result = PCC.certify(
            [family for _ in PCC.nodes(graph)],
            graph,
            problem;
            optimizer,
            gains,
        )
        @test PCC.is_feasible(result)
        @test minimum(PCC.edge_slacks(result)) >= -1e-6
        rng = Random.MersenneTwister(22)
        for edge in PCC.edges(graph), _ in 1:15
            x = Random.randn(rng, 2)
            a, b = PCC.source(edge), PCC.dest(edge)
            mode = only(PCC.letters(PCC.label(graph, edge)))
            next = (matrices[mode] + inputs[mode]*gains[a])*x
            stage = maximum(abs, x)^p + abs(only(gains[a]*x))^p
            @test PCC.node_value(problem, PCC.functions(result)[a], x) + 1e-6 >=
                  stage + PCC.node_value(problem, PCC.functions(result)[b], next)
        end
        trajectory = PCC.simulate(result, [1.0, -2.0], 60; rng)
        accumulated = sum(
            maximum(abs, x)^p + abs(only(u))^p for
            (x, u) in zip(PCC.states(trajectory), PCC.inputs(trajectory))
        )
        @test accumulated <= result([1.0, -2.0]) + 1e-5
    end
    initialized = PCC.certify(
        family,
        graph,
        PCC.OptimalControlProblem(system, partition, input_cost);
        optimizer = HiGHS.Optimizer,
        initialization_optimizer = OPTIMIZER,
    )
    @test PCC.is_feasible(initialized)
end

@testset "Piecewise quadratic optimal control" begin
    P = SetProg.Polyhedra
    library = P.DefaultLibrary{Float64}(HiGHS.Optimizer)
    box = P.polyhedron(P.hrep([1.0 0.0; 0.0 1.0; -1.0 0.0; 0.0 -1.0], ones(4)), library)
    diamond =
        P.polyhedron(P.hrep([1.0 1.0; 1.0 -1.0; -1.0 1.0; -1.0 -1.0], ones(4)), library)
    families = [
        SetProg.Ellipsoid(symmetric = true, piecewise = partition) for
        partition in (box, diamond)
    ]
    matrices = [[0.4 0.1; 0.0 0.3], [0.3 0.0; -0.1 0.4]]
    inputs = [[1.0; 0.0;;], [0.0; 1.0;;]]
    system = PCC.switched_system(matrices, inputs)
    graph = PCC.de_bruijn(1, 2)
    Q = [120.0 20.0; 20.0 90.0]
    R = [70.0;;]
    problem = PCC.OptimalControlProblem(system, Q, R)
    gains = [[-0.05 -0.05] for _ in PCC.nodes(graph)]
    margin = 0.01
    for template in (families, first(families))
        result = PCC.certify(template, graph, problem; optimizer = OPTIMIZER, gains, margin)
        @test PCC.is_feasible(result)
        @test result.gains == gains
        @test all(
            V -> V isa SetProg.Sets.Piecewise{<:Any, <:SetProg.Sets.Ellipsoid},
            PCC.functions(result),
        )
        @test minimum(PCC.edge_slacks(result)) >= -1e-6
        rng = Random.MersenneTwister(22)
        for edge in PCC.edges(graph), _ in 1:50
            x = Random.randn(rng, 2)
            a, b = PCC.source(edge), PCC.dest(edge)
            mode = only(PCC.letters(PCC.label(graph, edge)))
            u = gains[a]*x
            next = matrices[mode]*x + inputs[mode]*u
            cost =
                x'*Q*x +
                u'*R*u +
                margin * PCC._cost_scale(problem) * LinearAlgebra.dot(x, x)
            @test PCC.node_value(problem, PCC.functions(result)[a], x) + 1e-5 >=
                  cost + PCC.node_value(problem, PCC.functions(result)[b], next)
        end
        trajectory = PCC.simulate(result, [1.0, -2.0], 80; rng)
        cost = sum(
            x'*Q*x + u'*R*u for
            (x, u) in zip(PCC.states(trajectory), PCC.inputs(trajectory))
        )
        @test cost <= result([1.0, -2.0]) + 1e-5
        @test LinearAlgebra.norm(last(PCC.states(trajectory))) < 1e-8
    end
    initialized = PCC.certify(first(families), graph, problem; optimizer = OPTIMIZER)
    @test PCC.is_feasible(initialized)
    @test_throws ArgumentError PCC.optimization_model(
        first(families),
        graph,
        problem;
        optimizer = OPTIMIZER,
    )
    @test_throws MethodError PCC.certify(
        first(families),
        graph,
        PCC.OptimalControlProblem(system, Q, R; p = 4);
        optimizer = OPTIMIZER,
        gains,
    )
    interval = P.polyhedron(P.hrep([1.0; -1.0;;], ones(2)), library)
    family = SetProg.Ellipsoid(symmetric = true, piecewise = interval)
    scalar_system = PCC.switched_system([[0.5;;]], [[1.0;;]])
    scalar_problem = PCC.OptimalControlProblem(scalar_system, [100.0;;], [100.0;;])
    scalar = PCC.certify(
        family,
        PCC.common_graph(scalar_system),
        scalar_problem;
        optimizer = OPTIMIZER,
        gains = [[-0.1;;]],
    )
    @test PCC.is_feasible(scalar)
    @test scalar([2.0]) ≈ 100 * 1.01 / (1-0.4^2) * 4 rtol=1e-5
end

end
