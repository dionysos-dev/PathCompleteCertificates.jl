module TestDualPiecewiseLinear

using Test
using LinearAlgebra
using SetProg
import PathCompleteCertificates as PCC
import HiGHS

const OPTIMIZER = optimizer_with_attributes(HiGHS.Optimizer, MOI.Silent() => true)
const A = [[0.5 0.1; 0.0 0.25], [0.3 0.0; 0.1 0.4]]
const SYSTEM = PCC.switched_system(A)
const PROBLEM = PCC.StabilityProblem(SYSTEM)

@testset "on matrices, the template keeps orientations, symmetry and minimum weights" begin
    for n in (2, 3)
        G = Matrix{Float64}(I, n, n)
        G[1, 2] = 0.5
        family = only(PCC.DualPiecewiseLinearTemplate([G]; min_weight = 2))
        problem =
            PCC.StabilityProblem(PCC.switched_system([0.5 * Matrix{Float64}(I, n, n)]))
        graph = PCC.common_graph(1)
        @test family.set isa SetProg.Polytope
        @test family.set.piecewise isa Polyhedra.Polyhedron
        @test PCC.has_dual(family)
        @test PCC.dual(family) === family.set
        for (rate, feasible) in ((0.6, true), (0.4, false))
            c = PCC.certify(family, graph, problem; optimizer = OPTIMIZER, rate)
            @test PCC.is_feasible(c) == feasible
            feasible || continue
            V = only(PCC.functions(c))
            @test V isa SetProg.Sets.PolarOf{<:PCC._LinearPolytope}
            inner = polar(V)
            w = [PCC._polytope_value(inner, G[i, :]) for i in 1:n]
            @test all(>=(2 - 1e-7), w)
            for x in (ones(n), collect(1.0:n), -ones(n))
                v = PCC.node_value(problem, V, x)
                @test v ≈ maximum(abs.(G * x) ./ w)
                @test v ≈ PCC.node_value(problem, V, -x)
            end
            @test all(>=(-1e-7), PCC.edge_slacks(c))
        end
    end
end

@testset "one matrix per node, and the max lift needs one partition" begin
    matrices = [[1.0 0.5; 0.0 1.0], [2.0 0.0; 0.0 1.0]]
    families = PCC.DualPiecewiseLinearTemplate(matrices)
    graph = PCC.de_bruijn(1, 2)
    c = PCC.certify(families, graph, PROBLEM; optimizer = OPTIMIZER, rate = 0.9)
    @test PCC.is_feasible(c)
    @test all(>=(-1e-7), PCC.edge_slacks(c))
    @test !PCC.is_closed_under(families, PCC.Maximum(), SYSTEM)
    @test PCC.is_closed_under(fill(first(families), 2), PCC.Maximum(), SYSTEM)
end

@testset "the constructors check their arguments" begin
    @test_throws ArgumentError PCC.DualPiecewiseLinearTemplate([zeros(2, 2)])
    @test_throws ArgumentError PCC.DualPiecewiseLinearTemplate(0, 2)
    @test_throws ArgumentError PCC.DualPiecewiseLinearTemplate(1, 0)
    @test_throws ArgumentError PCC.DualPiecewiseLinearTemplate(1, 2; min_weight = 0)
    @test_throws ArgumentError PCC.DualPiecewiseLinearTemplate(Matrix{Float64}[])
    @test_throws DimensionMismatch PCC.DualPiecewiseLinearTemplate([ones(2, 2), ones(3, 3)])
end

end # module
