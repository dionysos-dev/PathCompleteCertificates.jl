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

@testset "the bound is a function of the state, and nonnegative" begin
    @test RESULT([1.0, 1.0]) > 0
    @test PCC.common(GRAPH, PROBLEM, PCC.functions(RESULT), [1.0, 1.0]) > 0
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

# --- The closed loop: the gain applied at each step is the one on the node the
# certificate graph is currently in, which the replay below walks independently.

@testset "the certificate drives the loop" begin
    @test PCC.is_feasible(RESULT)

    rng = Random.MersenneTwister(3)
    trajectory = PCC.simulate(RESULT, [1.0, 1.0], 20; rng = rng)

    @test PCC.has_input(trajectory)
    @test length(trajectory) == 20
    @test length(PCC.inputs(trajectory)) == 20
    @test length(PCC.states(trajectory)) == 21
end

@testset "the run starts where the bound is attained" begin
    x0 = [1.0, 1.0]
    values = [V(x0) for V in PCC.functions(RESULT)]
    trajectory = PCC.simulate(RESULT, x0, 1; rng = Random.MersenneTwister(1))

    @test first(PCC.inputs(trajectory)) ≈ RESULT.gains[argmin(values)] * x0
end

@testset "the gain follows the graph, not the step" begin
    rng = Random.MersenneTwister(3)
    trajectory = PCC.simulate(RESULT, [1.0, 1.0], 20; rng = rng, node = 1)

    xs = PCC.states(trajectory)
    us = PCC.inputs(trajectory)
    node = 1

    for (k, mode) in enumerate(PCC.switching(trajectory))
        @test us[k] ≈ RESULT.gains[node] * xs[k]
        @test xs[k + 1] ≈ A[mode] * xs[k] + B[mode] * us[k]

        node = PCC.dest(first(PCC.outgoing_edges(GRAPH, node, mode)))
    end

    # More than one node was visited, so the test above is not vacuous.
    @test PCC.n_nodes(GRAPH) > 1
    @test length(Set(PCC.switching(trajectory))) > 1
end

@testset "the closed loop contracts" begin
    rng = Random.MersenneTwister(5)
    xs = PCC.states(PCC.simulate(RESULT, [1.0, 1.0], 40; rng = rng))

    @test LinearAlgebra.norm(last(xs)) < LinearAlgebra.norm(first(xs))
end

@testset "input validation" begin
    @test_throws ArgumentError PCC.simulate(RESULT, [1.0, 1.0, 1.0], 5)
    @test_throws ArgumentError PCC.simulate(RESULT, [1.0, 1.0], 5; node = 99)
    @test_throws ArgumentError PCC.simulate(RESULT, [1.0, 1.0], -1)
end

@testset "a graph that cannot read a mode is refused" begin
    # Complete for its own alphabet, but blind to the system's second mode, so
    # the policy has nowhere to go the first time mode 2 is drawn.
    mode_1_only = GraphAutomaton(1)
    add_transition!(mode_1_only, 1, 1, 1)

    blind = PCC.OptimalControlCertificate(
        PCC.CertificateData(
            PROBLEM,
            PCC.QuadraticTemplate(),
            mode_1_only,
            PCC.functions(RESULT),
            PCC.status(RESULT),
            true,
        ),
        RESULT.gains,
    )

    @test_throws ArgumentError PCC.simulate(
        blind,
        [1.0, 1.0],
        30;
        rng = Random.MersenneTwister(1),
    )
end

@testset "the closed loop along given modes" begin
    trajectory = PCC.simulate(RESULT, [1.0, 1.0], [1, 2, 2]; node = 1)

    @test PCC.switching(trajectory) == [1, 2, 2]
    @test first(PCC.inputs(trajectory)) ≈ RESULT.gains[1] * [1.0, 1.0]
end

end
