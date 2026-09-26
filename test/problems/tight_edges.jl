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

end
