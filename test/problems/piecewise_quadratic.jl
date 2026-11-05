module TestPiecewiseQuadratic

using Test
using LinearAlgebra
using SetProg
# SetProg makes the pieces agree on the cone boundaries with SOS constraints.
using SumOfSquares
import PathCompleteCertificates as PCC
import Clarabel
import HiGHS

const LIB = Polyhedra.DefaultLibrary{Float64}(
    optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true),
)

# A rotation and a shear: no quadratic attains the joint spectral radius.
const A = [0.69 * [0.0 1.0; -1.0 0.0], 0.69 * [1.0 1.0; 0.0 1.0]]
const PROBLEM = PCC.StabilityProblem(PCC.switched_system(A))

@testset "the piecewise quadratic constructor" begin
    partition = PCC.planar_conic_partition(1; library = LIB)
    families = PCC.PiecewiseQuadraticTemplate([partition, partition])
    @test length(families) == 2
    @test all(f -> f isa Ellipsoid && f.piecewise === partition, families)
    @test all(f -> f.symmetric, families)
    @test PCC.homogeneity_degree(families) == 2
    system = PCC.switched_system(A)
    @test PCC.is_closed_under(first(families), PCC.Addition(), system)
    @test !PCC.is_closed_under(first(families), PCC.Composition(), system)
    @test_throws ArgumentError PCC.PiecewiseQuadraticTemplate([])
    @test_throws ArgumentError PCC.PiecewiseQuadraticTemplate([[Matrix{Float64}(I, 2, 2)]])
end

@testset "a piecewise quadratic certificate is piecewise, below the quadratic bound" begin
    partition = PCC.planar_conic_partition(1; library = LIB)
    template = PCC.PiecewiseQuadraticTemplate([partition])
    graph = PCC.common_graph(2)
    quadratic = PCC.certify(
        PCC.QuadraticTemplate(),
        graph,
        PROBLEM;
        optimizer = Clarabel.Optimizer,
        rtol = 1e-3,
    )
    certificate =
        PCC.certify(template, graph, PROBLEM; optimizer = Clarabel.Optimizer, rtol = 1e-3)

    @test PCC.is_feasible(certificate)
    @test only(PCC.functions(certificate)) isa SetProg.Sets.Piecewise
    # A quadratic form is quadratic on each cone, so the cones lower the bound.
    @test certificate.rate < quadratic.rate - 1e-2
end

end
