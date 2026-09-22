module TestOptimalControl

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import JuMP
import LinearAlgebra

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

@testset "`objective` is the log-determinant heuristic, not a value bound" begin
    # It is named `objective` because it is exactly the solved objective. A
    # value-function bound could not be negative here, since Q and R are
    # positive definite.
    log_det = sum(
        log(LinearAlgebra.det(inv(LinearAlgebra.Symmetric(Matrix(V))))) for
        V in PCC.functions(RESULT)
    )

    @test RESULT.objective ≈ log_det rtol = 1e-4
    @test RESULT.objective < 0

    # The bound itself is a function of the state, and it is nonnegative.
    @test PCC.common(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM,
        PCC.functions(RESULT),
        [1.0, 1.0],
    ) > 0
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
    # guard, `A, B = mode_matrices(system)` splits the two mode matrices into
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

end
