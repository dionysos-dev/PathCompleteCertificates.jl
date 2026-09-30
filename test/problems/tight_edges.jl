module TestTightEdges

# Slack is the quantity a refinement step reads: zero means the edge holds the
# bound up, and a node with two tight outgoing edges is the one to split.

using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra

const OPTIMIZER = Clarabel.Optimizer

# rho(A) = 0.5 exactly, and the quadratic template attains it, so the single
# self-loop is tight at the optimum.
const A = [[0.5 0.0; 0.0 0.25]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))
const GRAPH = PCC.de_bruijn(1, 1)

@testset "slack is nonnegative where the certificate holds" begin
    loose = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.9,
    )

    slacks = PCC.edge_slacks(loose)

    @test length(slacks) == PCC.n_edges(GRAPH)
    @test all(>=(-1e-7), slacks)

    # 0.9 is well above the true rate 0.5, so nothing is tight.
    @test isempty(PCC.tight_edges(loose))
    @test all(>(1e-3), slacks)
end

@testset "the bound is attained exactly where an edge goes tight" begin
    bound = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    )

    @test abs(bound.rate - 0.5) <= 0.01

    slacks = PCC.edge_slacks(bound)

    # At the optimal rate the self-loop is what holds the bound up.
    @test minimum(slacks) <= 1e-4
    @test !isempty(PCC.tight_edges(bound; atol = 1e-4))

    for (src, dst, mode) in PCC.tight_edges(bound; atol = 1e-4)
        @test src in PCC.nodes(GRAPH)
        @test dst in PCC.nodes(GRAPH)
        @test mode in eachindex(A)
    end
end

@testset "slack agrees with the inequality it measures" begin
    certificate = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.8,
    )

    V = PCC.functions(certificate)
    scale = 0.8^PCC.rate_exponent(PCC.QuadraticTemplate())

    for (edge, slack) in zip(PCC.edges(GRAPH), PCC.edge_slacks(certificate))
        src = V[PCC.source(edge)]
        dst = V[PCC.dest(edge)]
        map = A[PCC.label(GRAPH, edge)]

        residual = scale * src.P - transpose(map) * dst.P * map
        @test slack ≈ minimum(LinearAlgebra.eigvals(LinearAlgebra.Symmetric(residual)))

        # Slack ≥ 0 is exactly the edge inequality holding, sampled.
        for x in ([1.0, 0.0], [0.0, 1.0], [1.0, 1.0], [1.0, -2.0])
            @test scale * src(x) - dst(map * x) >= -1e-7
        end
    end
end

@testset "every template answers domination_slack" begin
    quadratic = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.9,
    )
    @test PCC.edge_slacks(quadratic) isa Vector

    polyhedral = PCC.certify(
        PCC.PolyhedralTemplate(PCC.n_nodes(GRAPH), 2),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.9,
    )
    @test all(>=(-1e-7), PCC.edge_slacks(polyhedral))

    conic = PCC.certify(
        PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(2)]),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.9,
    )
    @test all(>=(-1e-7), PCC.edge_slacks(conic))

    nonneg = PCC.StabilityProblem(PCC.switched_system([[0.4 0.1; 0.2 0.3]]))
    copositive = PCC.certify(
        PCC.LinearCopositiveTemplate(),
        PCC.de_bruijn(1, 1),
        nonneg;
        optimizer = OPTIMIZER,
        rate = 0.9,
    )
    @test all(>=(-1e-7), PCC.edge_slacks(copositive))
end

@testset "an infeasible certificate has nothing to measure" begin
    tight = PCC.certify(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rate = 0.1,
    )

    @test !PCC.is_feasible(tight)
    @test_throws ArgumentError PCC.edge_slacks(tight)
    @test_throws ArgumentError PCC.tight_edges(tight)
end

# --- The optimality certificate: Definition 4, Theorem 4 and Lemma 1 of
# --- Ninite & Jungers, arXiv:2607.00637.

# Two opposite rotations scaled by 0.9. Rotations preserve the Euclidean norm, so
# P = I is exact and the JSR is exactly 0.9 -- on any graph, with every edge
# tight. The case Theorem 4 cannot certify and the cycle bound can.
const THETA = pi / 3
const ROTATIONS = [
    0.9 .* [cos(THETA) -sin(THETA); sin(THETA) cos(THETA)],
    0.9 .* [cos(-THETA) -sin(-THETA); sin(-THETA) cos(-THETA)],
]
const ROTATION_PROBLEM = PCC.StabilityProblem(PCC.switched_system(ROTATIONS))
const TWO_NODES = PCC.de_bruijn(1, 2)

@testset "the tight subgraph keeps the nodes and drops the slack edges" begin
    certificate = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-8,
    )

    subgraph = PCC.tight_subgraph(certificate; atol = 1e-4)

    @test PCC.n_nodes(subgraph) == PCC.n_nodes(PCC.graph(certificate))
    @test PCC.n_edges(subgraph) == length(PCC.tight_edges(certificate; atol = 1e-4))
    @test PCC.n_edges(subgraph) <= PCC.n_edges(PCC.graph(certificate))

    # Nothing is tight at a huge tolerance... and everything is.
    @test PCC.n_edges(PCC.tight_subgraph(certificate; atol = -1.0)) == 0
    @test PCC.n_edges(PCC.tight_subgraph(certificate; atol = 1e3)) ==
          PCC.n_edges(PCC.graph(certificate))
end

@testset "a cycle bounds the JSR from below, whatever atol was" begin
    certificate = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        TWO_NODES,
        ROTATION_PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-8,
    )

    # Both modes are rotations of norm 0.9, so every cycle gives exactly 0.9 and
    # the bracket is closed: this graph attains the JSR.
    @test isapprox(PCC.jsr_lower_bound(certificate; atol = 1e-4), 0.9; atol = 1e-4)
    @test certificate.rate - PCC.jsr_lower_bound(certificate; atol = 1e-4) < 1e-4

    # The bound is never above the certified rate, which is what makes it a
    # bracket rather than two unrelated numbers.
    for atol in (1e-8, 1e-4, 1e-1)
        @test PCC.jsr_lower_bound(certificate; atol = atol) <= certificate.rate + 1e-6
    end

    # No cycles reachable within one edge here, so no bound -- and still sound.
    @test PCC.jsr_lower_bound(certificate; atol = -1.0) == 0
end

@testset "Theorem 4 is sufficient, not necessary" begin
    exact = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        TWO_NODES,
        ROTATION_PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-8,
    )

    # Every edge is tight, so every node has two tight outgoing edges and the
    # structural condition fails -- on a graph that attains the exact JSR. This
    # is why the cycle bracket exists.
    @test !PCC.is_jsr_exact(exact; atol = 1e-4)
    @test isapprox(exact.rate, 0.9; atol = 1e-3)

    # The one-mode system has a single tight self-loop, so the condition holds.
    single = PCC.jsr_bound(
        PCC.QuadraticTemplate(),
        GRAPH,
        PROBLEM;
        optimizer = OPTIMIZER,
        rtol = 1e-8,
    )

    @test PCC.is_jsr_exact(single; atol = 1e-4)
    @test isapprox(single.rate, 0.5; atol = 1e-3)
end

end
