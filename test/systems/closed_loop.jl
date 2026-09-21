module TestClosedLoop

# The property that matters: the gain applied at each step is the one sitting on
# the node the certificate graph is currently in, not a fixed one. Replaying the
# run with the node walked independently is what checks that.

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

const CERTIFICATE = PCC.optimal_control_certificate(
    PCC.QuadraticTemplate(),
    GRAPH,
    PROBLEM;
    optimizer = OPTIMIZER,
)

@testset "the certificate drives the loop" begin
    @test PCC.is_feasible(CERTIFICATE)

    rng = Random.MersenneTwister(3)
    trajectory = PCC.simulate(CERTIFICATE, [1.0, 1.0], 20; rng = rng)

    @test PCC.has_input(trajectory)
    @test length(trajectory) == 20
    @test length(PCC.inputs(trajectory)) == 20
    @test length(PCC.states(trajectory)) == 21
end

@testset "the gain follows the graph, not the step" begin
    rng = Random.MersenneTwister(3)
    trajectory = PCC.simulate(CERTIFICATE, [1.0, 1.0], 20; rng = rng)

    xs = PCC.states(trajectory)
    us = PCC.inputs(trajectory)
    node = 1

    for (k, mode) in enumerate(PCC.switching(trajectory))
        @test us[k] ≈ CERTIFICATE.gains[node] * xs[k]
        @test xs[k + 1] ≈ A[mode] * xs[k] + B[mode] * us[k]

        node = PCC.dest(first(PCC.outgoing_edges(GRAPH, node, mode)))
    end

    # More than one node was visited, so the test above is not vacuous.
    @test PCC.n_nodes(GRAPH) > 1
    @test length(Set(PCC.switching(trajectory))) > 1
end

@testset "the closed loop contracts" begin
    rng = Random.MersenneTwister(5)
    xs = PCC.states(PCC.simulate(CERTIFICATE, [1.0, 1.0], 40; rng = rng))

    @test LinearAlgebra.norm(last(xs)) < LinearAlgebra.norm(first(xs))
end

@testset "input validation" begin
    @test_throws ArgumentError PCC.simulate(CERTIFICATE, [1.0, 1.0, 1.0], 5)
    @test_throws ArgumentError PCC.simulate(CERTIFICATE, [1.0, 1.0], 5; node = 99)
    @test_throws ArgumentError PCC.simulate(CERTIFICATE, [1.0, 1.0], -1)
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
            PCC.functions(CERTIFICATE),
            PCC.status(CERTIFICATE),
            true,
        ),
        CERTIFICATE.gains,
        CERTIFICATE.objective,
    )

    @test_throws ArgumentError PCC.simulate(
        blind,
        [1.0, 1.0],
        30;
        rng = Random.MersenneTwister(1),
    )
end

end
