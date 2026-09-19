module TestConicPolyhedral

# The general polyhedral template of Dionysos `compute_polyhedral_pieces_pclf`:
# the facets are decision variables, and each node carries a conic partition of
# the state space so that the max can be linearised.
using Test
using HybridSystems
import PathCompleteCertificates as PCC
import Clarabel
import LinearAlgebra
using LinearAlgebra: normalize

const OPTIMIZER = Clarabel.Optimizer

# rho(A) = 0.5, and the identity template certifies it exactly: the weighted
# infinity norm with w = (1, 1) is already a Lyapunov function here.
const A = [[0.5 0.0; 0.0 0.25]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)

const GRAPH = GraphAutomaton(2)
add_transition!(GRAPH, 1, 2, 1)
add_transition!(GRAPH, 2, 1, 1)

@testset "planar conic partitions" begin
    for order in 1:4
        cones = PCC.planar_conic_partition(order)

        @test length(cones) == 4 * 2^(order - 1)
        @test all(size(cone) == (2, 2) for cone in cones)

        # Consecutive cones share a ray, and together they sweep the upper
        # half-plane from (1, 0) to (-1, 0).
        @test cones[1][:, 1] == [1.0, 0.0]
        @test normalize(cones[end][:, 2]) ≈ [-1.0, 0.0]

        for i in 1:(length(cones) - 1)
            @test normalize(cones[i][:, 2]) ≈ normalize(cones[i + 1][:, 1])
        end
    end

    @test_throws ArgumentError PCC.planar_conic_partition(0)
end

@testset "the conic template solves for its facets" begin
    cones = PCC.planar_conic_partition(2)
    template = PCC.ConicPolyhedralTemplate([cones, cones])

    @test PCC.rate_exponent(template) == 1

    result = PCC.jsr_bound(template, GRAPH, PROBLEM; optimizer = OPTIMIZER, rtol = 1e-3)

    @test result.feasible
    @test abs(result.bound - 0.5) <= 0.01

    # One facet row per cone, and the scale that keeps V away from zero.
    @test size(result.V[1].P) == (length(cones), 2)
    @test result.V[1].scale >= 1e-3 - 1e-9

    # The edge condition is imposed only on the cones' extreme rays; check it
    # actually holds everywhere, which is the point of the dominance
    # constraints.
    for edge in PCC.edges(GRAPH)
        src = PCC.source(edge)
        dst = PCC.dest(edge)
        mode = PCC.label(GRAPH, edge)

        for theta in range(0, 2pi; length = 400)
            x = [cos(theta), sin(theta)]
            @test result.V[dst](A[mode] * x) <= result.bound * result.V[src](x) + 1e-6
        end
    end
end

@testset "free facets beat fixed ones, and refine toward the true rate" begin
    # A rotation scaled by 0.9. Its JSR is 0.9, but no weighted infinity norm
    # in the standard coordinates gets near it -- the 2n-face template cannot
    # even certify contraction, while refining the partition drives the conic
    # template down to the true rate.
    theta = pi / 3
    rotated = 0.9 * [cos(theta) -sin(theta); sin(theta) cos(theta)]

    graph = GraphAutomaton(1)
    add_transition!(graph, 1, 1, 1)
    problem = PCC.StabilityProblem(PCC.switched_system([rotated]))

    fixed = PCC.jsr_bound(
        PCC.PolyhedralTemplate(1, 2),
        graph,
        problem;
        optimizer = OPTIMIZER,
        rtol = 1e-4,
    ).bound

    @test fixed > 1.0     # certifies nothing about contraction

    bounds = map(1:4) do order
        template = PCC.ConicPolyhedralTemplate([PCC.planar_conic_partition(order)])
        PCC.jsr_bound(template, graph, problem; optimizer = OPTIMIZER, rtol = 1e-4).bound
    end

    @test all(>=(0.9 - 1e-4), bounds)          # never below the true JSR
    @test all(<(fixed), bounds)                # all better than fixed facets
    @test issorted(bounds; rev = true)         # refining never hurts
    @test bounds[end] <= 0.91                  # and converges to 0.9
end

@testset "the conic template validates its partition" begin
    cones = PCC.planar_conic_partition(1)

    @test_throws ArgumentError PCC.ConicPolyhedralTemplate(Vector{Matrix{Float64}}[])
    @test_throws ArgumentError PCC.ConicPolyhedralTemplate([Matrix{Float64}[]])
    @test_throws ArgumentError PCC.ConicPolyhedralTemplate([cones]; min_scale = 0.0)

    # Cones of mismatched dimension.
    @test_throws ArgumentError PCC.ConicPolyhedralTemplate([[cones[1], ones(3, 2)]])

    # A partition for fewer nodes than the graph has.
    single = PCC.ConicPolyhedralTemplate([cones])
    @test_throws ArgumentError PCC.jsr_bound(single, GRAPH, PROBLEM; optimizer = OPTIMIZER)
end

end
