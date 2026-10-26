module TestOptimalControl

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import JuMP
import LinearAlgebra
import Random

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

end
