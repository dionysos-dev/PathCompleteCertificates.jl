module TestPiecewiseLinear

using Test
using LinearAlgebra
using SetProg
import PathCompleteCertificates as PCC
import Clarabel
import HiGHS

const LIB = Polyhedra.DefaultLibrary{Float64}(
    optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true),
)

@testset "Planar partition polytopes" begin
    for order in 1:3
        partition = PCC.planar_conic_partition(order; library = LIB)
        @test partition isa Polyhedra.Polyhedron
        @test fulldim(partition) == 2
        @test npoints(partition) == nhalfspaces(partition) == 8 * 2^(order - 1)
        @test all(h -> h.β > 0, halfspaces(partition))
        @test all(v -> -v in partition, points(partition))
        pieces = [SetProg.Sets.PolarPoint(h.a / h.β) for h in halfspaces(partition)]
        set = SetProg.Sets.Piecewise(pieces, partition)
        @test all(neighbors -> length(neighbors) == 2, set.graph)
        # Refinement preserves the original axes and diagonal boundary rays.
        for r in ([1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [-1.0, 1.0])
            @test any(v -> v ≈ r / norm(r), points(partition))
        end
    end
    @test PCC.planar_conic_partition(1) isa Polyhedra.Polyhedron
    @test_throws ArgumentError PCC.planar_conic_partition(0)
end

@testset "the piecewise linear constructor" begin
    partition = PCC.planar_conic_partition(1; library = LIB)
    families = PCC.PiecewiseLinearTemplate([partition, partition])
    @test length(families) == 2
    @test all(f -> f isa Polytope && f.piecewise === partition, families)
    @test all(f -> f.symmetric && f.dimension == 2, families)
    system = PCC.switched_system([[0.5 0.0; 0.0 0.25]])
    @test PCC.is_closed_under(first(families), PCC.Addition(), system)
    @test !PCC.is_closed_under(first(families), PCC.Maximum(), system)
    @test !PCC.is_closed_under(first(families), PCC.Composition(), system)
    @test !PCC.is_closed_under(first(families), PCC.InverseComposition(), system)
    @test !PCC.is_closed_under(families, PCC.Maximum(), system)
    scaled = only(PCC.PiecewiseLinearTemplate([partition]; min_scale = 2))
    @test all(v -> 2v in partition, points(scaled.piecewise))
    @test_throws ArgumentError PCC.PiecewiseLinearTemplate([])
    @test_throws ArgumentError PCC.PiecewiseLinearTemplate([[Matrix{Float64}(I, 2, 2)]])
    @test_throws ArgumentError PCC.PiecewiseLinearTemplate([partition]; min_scale = 0)
    @test_throws ArgumentError PCC.PiecewiseLinearTemplate([partition]; min_scale = Inf)
end

@testset "a piecewise linear certificate matches the SetProg polytope family" begin
    A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
    problem = PCC.StabilityProblem(PCC.switched_system(A))
    graph = PCC.common_graph(2)
    partition = PCC.planar_conic_partition(1; library = LIB)
    families = PCC.PiecewiseLinearTemplate([partition])
    # This octagon has the facet cones of `planar_conic_partition(1)`, with other vertex radii.
    octagon = polyhedron(
        hrep([
            HalfSpace(a, 6.0) for a in (
                [2.0, 1.0],
                [1.0, 2.0],
                [-1.0, 2.0],
                [-2.0, 1.0],
                [-2.0, -1.0],
                [-1.0, -2.0],
                [1.0, -2.0],
                [2.0, -1.0],
            )
        ]),
        LIB,
    )
    polytope = Polytope(symmetric = true, piecewise = octagon)
    linear =
        PCC.certify(families, graph, problem; optimizer = Clarabel.Optimizer, rtol = 1e-3)
    baseline =
        PCC.certify(polytope, graph, problem; optimizer = Clarabel.Optimizer, rtol = 1e-3)
    @test PCC.is_feasible(linear)
    @test PCC.is_feasible(baseline)
    @test abs(linear.rate - baseline.rate) <= 2e-3
    @test all(>=(-1e-6), PCC.edge_slacks(linear))
    V = only(PCC.functions(linear))
    @test V isa SetProg.Sets.Piecewise
    @test V.polytope === partition
    @test linear([1.0, 1.0]) > 0
    for map in A, θ in range(0, 2π; length = 97)
        x = [cos(θ), sin(θ)]
        value = PCC.node_value(problem, V, x)
        @test value > 0
        @test linear.rate * value - PCC.node_value(problem, V, map * x) >= -1e-5
    end
    # Higher-order partitions also return meaningful edge slacks.
    diagonal = PCC.StabilityProblem(PCC.switched_system([[0.5 0.0; 0.0 0.25]]))
    refined = PCC.PiecewiseLinearTemplate([PCC.planar_conic_partition(2; library = LIB)])
    certificate = PCC.certify(
        refined,
        PCC.de_bruijn(1, 1),
        diagonal;
        optimizer = Clarabel.Optimizer,
        rate = 0.9,
    )
    @test PCC.is_feasible(certificate)
    @test all(>=(-1e-6), PCC.edge_slacks(certificate))
    infeasible = PCC.certify(
        refined,
        PCC.de_bruijn(1, 1),
        diagonal;
        optimizer = Clarabel.Optimizer,
        rate = 0.4,
    )
    @test !PCC.is_feasible(infeasible)
end

end
